import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
import json
import os
import textwrap
from functools import partial
import copy # 用於深度複製物件


def attach_prefix_trace(tk_var, prefix):
    """確保 StringVar 內容自動補上指定前綴"""
    if not prefix or not isinstance(tk_var, tk.StringVar):
        return

    def _handler(*_):
        value = tk_var.get()
        if not value:
            return
        if not value.startswith(prefix):
            tk_var.set(f"{prefix}{value}")

    tk_var.trace_add('write', _handler)
    # 立即校正當前值
    current_value = tk_var.get()
    if current_value and not current_value.startswith(prefix):
        tk_var.set(f"{prefix}{current_value}")

# -------------------------------------------------------------------
# 核心功能：動態效果編輯器彈窗
# -------------------------------------------------------------------
class EffectEditorWindow(tk.Toplevel):
    """
    一個動態彈窗，用於新增或編輯單個技能效果 (effect)。
    它會根據 "effect_type" 自動生成對應的表單欄位。
    """
    def __init__(self, parent, effect_schema, all_effect_types,
                 element_options, effect_descriptions, # <-- 1. 參數已修正
                 element_cn_to_en=None, element_en_to_cn=None,  # <-- 新增映射參數
                 current_effect_data=None, callback=None):

        super().__init__(parent)
        self.transient(parent) # 保持在頂層
        self.grab_set() # 鎖定焦點
        self.geometry("450x450") # 保持較高的高度以容納提示

        self.effect_schema = effect_schema
        self.all_effect_types = all_effect_types
        self.element_options = element_options
        self.effect_descriptions = effect_descriptions # <-- 儲存字典
        # ✅ 儲存元素映射字典
        self.ELEMENT_CN_TO_EN = element_cn_to_en or {}
        self.ELEMENT_EN_TO_CN = element_en_to_cn or {}
        self.callback = callback
        
        # self.effect_data 用於儲存正在編輯的資料
        if current_effect_data:
            self.title("編輯效果")
            self.effect_data = copy.deepcopy(current_effect_data)
        else:
            self.title("新增效果")
            self.effect_data = {} # 空白物件

        self.widget_vars = {} # 儲存此彈窗的 tk 變數

        # --- 1. 頂部框架：效果類型 (Effect Type) ---
        top_frame = ttk.Frame(self)
        top_frame.pack(fill='x', padx=10, pady=10)
        
        ttk.Label(top_frame, text="效果類型 (Effect Type)", width=15).pack(side=tk.LEFT)
        
        self.effect_type_var = tk.StringVar(value=self.effect_data.get("effect_type"))
        self.effect_type_combo = ttk.Combobox(
            top_frame, 
            textvariable=self.effect_type_var, 
            values=self.all_effect_types, 
            state='readonly'
        )
        self.effect_type_combo.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        
        # 綁定事件，當 effect_type 改變時，重建下方的動態表單
        self.effect_type_combo.bind('<<ComboboxSelected>>', self.rebuild_dynamic_fields)
        
        # --- (錯誤 2：刪除這裡重複的 top_frame 代碼) ---

        # --- 4. 新增：提示標籤 (Tooltip Label) ---
        self.description_label = ttk.Label(
            self, 
            text="[請選擇一個效果類型]", 
            wraplength=430, # 自動換行
            justify=tk.LEFT,
            foreground="blue" # 提示文字用藍色
        )
        self.description_label.pack(fill='x', padx=12, pady=(0, 5))

        ttk.Separator(self).pack(fill='x', padx=10)

        # --- 2. 中間框架：動態參數 (Dynamic Parameters) ---
        self.dynamic_frame_container = ttk.Frame(self)
        self.dynamic_frame_container.pack(fill='both', expand=True, padx=10, pady=10)

        # --- 3. 底部框架：儲存/取消 ---
        bottom_frame = ttk.Frame(self)
        bottom_frame.pack(side=tk.BOTTOM, fill='x', padx=10, pady=10)
        
        ttk.Button(bottom_frame, text="取消", command=self.destroy).pack(side=tk.RIGHT, padx=5)
        ttk.Button(bottom_frame, text="儲存效果", command=self.save_effect, style='Accent.TButton').pack(side=tk.RIGHT)
        
        # --- 初始建構 ---
        if current_effect_data:
            self.rebuild_dynamic_fields(None) # 手動觸發一次以載入提示和表單

    def rebuild_dynamic_fields(self, event):
        """
        (核心) 清空並重建動態表單，並更新提示文字。
        (v0.5 - 添加參數提示)
        """
        # 清空舊的元件和變數
        for widget in self.dynamic_frame_container.winfo_children():
            widget.destroy()
        self.widget_vars = {}
        
        selected_type = self.effect_type_var.get()

        # --- 1. 更新 "效果類型" 的提示 ---
        if selected_type in self.effect_descriptions:
            self.description_label.config(text=self.effect_descriptions[selected_type])
        elif selected_type:
            self.description_label.config(text=f"提示：找不到 {selected_type} 的說明。")
        else:
            self.description_label.config(text="[請選擇一個效果類型]")

        if not selected_type:
            return

        self.effect_data["effect_type"] = selected_type
        params = self.effect_schema.get(selected_type)
        
        if params is None:
            ttk.Label(self.dynamic_frame_container, text="此效果類型沒有額外參數。").pack()
            return

        # --- 2. 動態建立表單 (已修改) ---
        for param_name, param_type, hint_text in params: # <-- 2.1. 解包 3 個項目
            
            # 建立一個框架來容納 "輸入列" 和 "提示列"
            row_frame = ttk.Frame(self.dynamic_frame_container)
            row_frame.pack(fill='x', pady=2)
            
            # --- 2.2. 輸入列 (標籤 + 輸入框) ---
            input_row_frame = ttk.Frame(row_frame)
            input_row_frame.pack(fill='x')

            ttk.Label(input_row_frame, text=param_name, width=18).pack(side=tk.LEFT)
            
            current_value = self.effect_data.get(param_name)
            widget = None # 預先宣告

            if param_type == "int_spin":
                var = tk.IntVar(value=int(current_value or 0))
                widget = ttk.Spinbox(input_row_frame, from_=-9999, to=9999, textvariable=var)
                self.widget_vars[param_name] = var
                
            elif param_type == "float_spin":
                var = tk.DoubleVar(value=float(current_value or 0.0))
                widget = ttk.Spinbox(input_row_frame, from_=-9999.0, to=9999.0, increment=0.1, textvariable=var)
                self.widget_vars[param_name] = var
                
            elif param_type == "element_combo":
                # 顯示中文，存儲英文
                current_en = current_value or ""
                current_cn = self.ELEMENT_EN_TO_CN.get(current_en, "")

                display_var = tk.StringVar(value=current_cn)
                cn_options = [self.ELEMENT_EN_TO_CN.get(e, e) for e in self.element_options]
                widget = ttk.Combobox(input_row_frame, textvariable=display_var, values=cn_options, state='readonly')

                # 創建隱藏變量存儲英文值
                en_var = tk.StringVar(value=current_en)
                self.widget_vars[param_name] = en_var

                # 當選擇改變時更新英文值
                def on_element_change(event, dv=display_var, ev=en_var):
                    selected_cn = dv.get()
                    actual_en = self.ELEMENT_CN_TO_EN.get(selected_cn, "")
                    ev.set(actual_en)

                widget.bind('<<ComboboxSelected>>', on_element_change)

            elif param_type == "combo":
                # ✅ 新增：通用下拉選單 (根據參數名稱提供選項)
                var = tk.StringVar(value=current_value or "")

                # 根據參數名稱提供對應的選項
                combo_options = []
                if param_name == "target_scope":
                    combo_options = ["SELF", "ALL_ALLIES"]
                elif param_name == "target_stat":
                    combo_options = ["base_atk", "base_hp", "base_recovery"]
                elif param_name == "target_rarity":
                    combo_options = ["", "R", "SR", "SSR"]  # 空白表示不篩選
                else:
                    combo_options = []  # 未知參數，保持空白

                widget = ttk.Combobox(input_row_frame, textvariable=var, values=combo_options, state='readonly')
                self.widget_vars[param_name] = var

            else: # 預設為 "entry"
                var = tk.StringVar(value=current_value)
                widget = ttk.Entry(input_row_frame, textvariable=var)
                self.widget_vars[param_name] = var
            
            if widget:
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

            # --- 2.3. (新功能) 提示列 ---
            if hint_text:
                hint_label_frame = ttk.Frame(row_frame) # 在主 row_frame 中新增一個框架
                hint_label_frame.pack(fill='x')
                
                # 添加一個空白標籤來對齊
                ttk.Label(hint_label_frame, width=18).pack(side=tk.LEFT) 
                
                # 顯示提示文字
                ttk.Label(
                    hint_label_frame,
                    text=hint_text,
                    foreground="grey",
                    font=("Arial", 8) # 使用小字體
                ).pack(side=tk.LEFT, fill='x', expand=True, padx=5)

    def save_effect(self):
        """儲存並關閉彈窗"""
        self.effect_data["effect_type"] = self.effect_type_var.get()
        if not self.effect_data["effect_type"]:
            messagebox.showerror("錯誤", "必須選擇一個效果類型 (Effect Type)", parent=self)
            return

        for param_name, var in self.widget_vars.items():
            self.effect_data[param_name] = var.get()
            
        if self.callback:
            self.callback(self.effect_data)
            
        self.destroy()


# -------------------------------------------------------------------
# 核心功能：整體技能編輯彈窗
# -------------------------------------------------------------------
class SkillEditorWindow(tk.Toplevel):
    """提供在任何地方快速建立 / 編輯技能的彈窗。"""

    def __init__(self, parent, *, data_key, id_key, name_key,
                 skill_data, effect_types, schema, element_options,
                 effect_descriptions, element_cn_to_en=None, element_en_to_cn=None,
                 on_save, id_prefix=""):

        super().__init__(parent)
        self.transient(parent)
        self.grab_set()
        self.geometry("600x650")
        self.title("技能編輯器")

        self.data_key = data_key
        self.id_key = id_key
        self.name_key = name_key
        self.id_prefix = id_prefix or ""
        self.on_save = on_save

        self.schema = schema
        self.effect_types = effect_types
        self.element_options = element_options
        self.effect_descriptions = effect_descriptions
        # ✅ 儲存元素映射字典
        self.element_cn_to_en = element_cn_to_en or {}
        self.element_en_to_cn = element_en_to_cn or {}

        self.working_data = copy.deepcopy(skill_data)
        self.original_id = skill_data.get(id_key)

        self._build_ui()

    def _build_ui(self):
        container = ttk.Frame(self)
        container.pack(fill='both', expand=True, padx=12, pady=12)

        ttk.Label(container, text="基本資訊", style='Title.TLabel').pack(anchor='w')

        form_frame = ttk.Frame(container)
        form_frame.pack(fill='x', pady=5)

        self.id_var = tk.StringVar(value=self.working_data.get(self.id_key, ""))
        attach_prefix_trace(self.id_var, self.id_prefix)
        self._create_entry_row(form_frame, "Skill ID", self.id_var)

        self.name_var = tk.StringVar(value=self.working_data.get(self.name_key, ""))
        self._create_entry_row(form_frame, "名稱", self.name_var)

        ttk.Label(form_frame, text="描述", width=15).pack(anchor='w')
        self.desc_text = tk.Text(form_frame, height=3)
        self.desc_text.insert(tk.END, self.working_data.get('description', ""))
        self.desc_text.pack(fill='x', pady=(0, 5))

        if self.data_key == 'active_skills':
            ttk.Label(container, text="主動技能屬性", style='Title.TLabel').pack(anchor='w', pady=(10, 0))
            active_frame = ttk.Frame(container)
            active_frame.pack(fill='x', pady=5)
            self.skill_cost_var = tk.IntVar(value=int(self.working_data.get('skill_cost', 0)))
            self._create_entry_row(active_frame, "冷卻 (skill_cost)", self.skill_cost_var)
            self.duration_var = tk.IntVar(value=int(self.working_data.get('duration', 0)))
            self._create_entry_row(active_frame, "持續 (duration)", self.duration_var)
            # 目標類型（顯示中文，存儲英文）
            current_target_en = self.working_data.get('target_type', 'SELF')
            current_target_cn = self.parent.TARGET_EN_TO_CN.get(current_target_en, '自己')

            self.target_type_display_var = tk.StringVar(value=current_target_cn)
            self.target_type_var = tk.StringVar(value=current_target_en)

            target_row = ttk.Frame(active_frame); target_row.pack(fill='x', pady=2)
            ttk.Label(target_row, text="目標", width=15).pack(side=tk.LEFT)
            target_combo = ttk.Combobox(
                target_row,
                textvariable=self.target_type_display_var,
                state='readonly',
                values=list(self.parent.TARGET_CN_TO_EN.keys())
            )
            target_combo.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

            def on_target_change(event):
                selected_cn = self.target_type_display_var.get()
                actual_en = self.parent.TARGET_CN_TO_EN.get(selected_cn, 'SELF')
                self.target_type_var.set(actual_en)

            target_combo.bind('<<ComboboxSelected>>', on_target_change)

        ttk.Separator(container).pack(fill='x', pady=10)
        ttk.Label(container, text="技能效果", style='Title.TLabel').pack(anchor='w')

        effect_frame = ttk.Frame(container)
        effect_frame.pack(fill='both', expand=True)

        self.effects_list = self.working_data.setdefault('effects', [])
        self.effects_listbox = tk.Listbox(effect_frame, height=8, exportselection=False)
        self.effects_listbox.pack(side=tk.LEFT, fill='both', expand=True, padx=(0, 5))

        for i, effect in enumerate(self.effects_list):
            self.effects_listbox.insert(
                tk.END,
                self._format_effect_display(effect.get('effect_type'))
            )

        btn_frame = ttk.Frame(effect_frame)
        btn_frame.pack(side=tk.LEFT)

        ttk.Button(btn_frame, text="新增效果", command=self.add_effect).pack(pady=2)
        ttk.Button(btn_frame, text="編輯選定", command=self.edit_effect).pack(pady=2)
        ttk.Button(btn_frame, text="移除選定", command=self.remove_effect).pack(pady=2)

        ttk.Separator(container).pack(fill='x', pady=10)
        action_frame = ttk.Frame(container)
        action_frame.pack(fill='x')
        ttk.Button(action_frame, text="取消", command=self.destroy).pack(side=tk.RIGHT, padx=5)
        ttk.Button(action_frame, text="儲存", command=self.save_skill, style='Accent.TButton').pack(side=tk.RIGHT)

    def _create_entry_row(self, parent, label, variable):
        row = ttk.Frame(parent)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text=label, width=15).pack(side=tk.LEFT)
        if isinstance(variable, (tk.IntVar, tk.DoubleVar)):
            entry = ttk.Entry(row, textvariable=variable)
        else:
            entry = ttk.Entry(row, textvariable=variable)
        entry.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

    def add_effect(self):
        EffectEditorWindow(
            self,
            self.schema,
            self.effect_types,
            self.element_options,
            self.effect_descriptions,
            self.element_cn_to_en,  # ✅ 使用自己的映射
            self.element_en_to_cn,  # ✅ 使用自己的映射
            current_effect_data=None,
            callback=self._on_effect_saved
        )

    def edit_effect(self):
        if not self.effects_listbox.curselection():
            return
        index = self.effects_listbox.curselection()[0]
        current_effect = self.effects_list[index]
        EffectEditorWindow(
            self,
            self.schema,
            self.effect_types,
            self.element_options,
            self.effect_descriptions,
            self.element_cn_to_en,  # ✅ 使用自己的映射
            self.element_en_to_cn,  # ✅ 使用自己的映射
            current_effect_data=current_effect,
            callback=lambda data: self._on_effect_saved(data, index)
        )

    def remove_effect(self):
        if not self.effects_listbox.curselection():
            return
        index = self.effects_listbox.curselection()[0]
        self.effects_list.pop(index)
        self._refresh_effect_listbox()

    def _refresh_effect_listbox(self):
        self.effects_listbox.delete(0, tk.END)
        for i, effect in enumerate(self.effects_list):
            self.effects_listbox.insert(
                tk.END,
                self._format_effect_display(effect.get('effect_type'))
            )

    def _on_effect_saved(self, effect_data, index=None):
        if index is None:
            self.effects_list.append(effect_data)
        else:
            self.effects_list[index] = effect_data
        self._refresh_effect_listbox()

    def _format_effect_display(self, effect_type):
        effect_id = effect_type or 'UNKNOWN'
        desc = self.effect_descriptions.get(effect_id, effect_id)
        return f"{desc}\n{effect_id}"

    def save_skill(self):
        skill_id = self.id_var.get().strip()
        if self.id_prefix and skill_id and not skill_id.startswith(self.id_prefix):
            skill_id = f"{self.id_prefix}{skill_id}"
            self.id_var.set(skill_id)
        skill_name = self.name_var.get().strip()
        if not skill_id:
            messagebox.showerror("錯誤", "Skill ID 不可為空", parent=self)
            return
        if not skill_name:
            messagebox.showerror("錯誤", "技能名稱不可為空", parent=self)
            return

        self.working_data[self.id_key] = skill_id
        self.working_data[self.name_key] = skill_name
        self.working_data['description'] = self.desc_text.get("1.0", tk.END).strip()

        if self.data_key == 'active_skills':
            self.working_data['skill_cost'] = self.skill_cost_var.get()
            self.working_data['duration'] = self.duration_var.get()
            self.working_data['target_type'] = self.target_type_var.get()

        if self.on_save and self.on_save(self.working_data, self.original_id):
            self.destroy()

    @staticmethod
    def format_description_text(raw_text: str) -> str:
        sanitized = (raw_text or "").replace('\r\n', '\n')
        sanitized = sanitized.rstrip('\n')
        return sanitized.replace('\n', r'\n')

# -------------------------------------------------------------------
# 主應用程式
# -------------------------------------------------------------------
class GameEditorApp:
    def __init__(self, root):
        self.root = root
        self.root.title("遊戲編輯器 (v1.1 - 完整版)")
        self.root.geometry("1100x750")
        self._setup_styles()

        # --- 變數 ---
        self.data_path = None
        self.data_cache = {}
        self.current_selected_card_id = None
        self.current_selected_enemy_id = None
        self.widget_vars = {}
        self.skill_widget_vars = {} # 用於技能編輯分頁
        self.enemy_skill_widget_vars = {} # 用於敵技編輯分頁
        self.skill_tab_meta = {} # 儲存技能分頁 listbox 的欄位資訊
        self._data_file_snapshot = {}
        self._auto_refresh_job = None
        self.auto_refresh_interval_ms = 2000  # 2 秒檢查一次資料夾變化
        self.SKILL_ID_PREFIXES = {
            'leader_skills': 'LS_',
            'active_skills': 'AS_',
            'enemy_skills': 'ES_'
        }

        # 檔案相對路徑
        self.FILE_PATHS = {
            "cards": "cards.json",
            "enemies": "enemies.json",
            "stages": "stages.json",  # 關卡配置
            "active_skills": os.path.join("config", "active_skills.json"),
            "leader_skills": os.path.join("config", "leader_skills.json"),
            "enemy_skills": os.path.join("config", "enemy_skills.json"),
            "regions": os.path.join("config", "regions.json"),  # 區域/章節配置
            "shop_items": os.path.join("config", "shop_items.json"),  # 商城物品
            "gacha_pools": os.path.join("config", "gacha_pools.json"),  # 抽卡池
            "training_rooms": os.path.join("config", "training_rooms.json")  # 訓練室
        }

        self._init_skill_metadata()
        self._build_base_ui()

    def _setup_styles(self):
        base_bg = '#edf2fb'
        self.root.configure(bg=base_bg)
        style = ttk.Style()
        try:
            style.theme_use('clam')
        except tk.TclError:
            pass
        style.configure('TFrame', background=base_bg)
        style.configure('TLabel', background=base_bg, font=("Noto Sans TC", 10))
        style.configure('Title.TLabel', background=base_bg, font=("Noto Sans TC", 12, 'bold'), foreground='#1f2937')
        style.configure('TButton', padding=(8, 4))
        style.configure('Accent.TButton', padding=(10, 5), background='#2563eb', foreground='white')
        style.map('Accent.TButton', background=[('active', '#1d4ed8')])
        style.configure('TNotebook.Tab', padding=(12, 6))

    def bind_mousewheel(self, canvas):
        """綁定鼠標滾輪事件到 Canvas（只在鼠標懸停時生效）"""
        def on_mousewheel(event):
            # Windows 和 Mac
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

        def on_mousewheel_linux_up(event):
            # Linux 向上滾動
            canvas.yview_scroll(-1, "units")

        def on_mousewheel_linux_down(event):
            # Linux 向下滾動
            canvas.yview_scroll(1, "units")

        def on_enter(event):
            # 鼠標進入 Canvas 時綁定滾輪事件
            canvas.bind_all("<MouseWheel>", on_mousewheel)  # Windows/Mac
            canvas.bind_all("<Button-4>", on_mousewheel_linux_up)  # Linux 向上
            canvas.bind_all("<Button-5>", on_mousewheel_linux_down)  # Linux 向下

        def on_leave(event):
            # 鼠標離開 Canvas 時解綁滾輪事件
            canvas.unbind_all("<MouseWheel>")
            canvas.unbind_all("<Button-4>")
            canvas.unbind_all("<Button-5>")

        # 綁定鼠標進入/離開事件
        canvas.bind("<Enter>", on_enter)
        canvas.bind("<Leave>", on_leave)

    def get_skill_id_prefix(self, data_key):
        return self.SKILL_ID_PREFIXES.get(data_key, "")

    def ensure_skill_id_prefix(self, data_key, skill_id):
        prefix = self.get_skill_id_prefix(data_key)
        cleaned = (skill_id or "").strip()
        if prefix and cleaned and not cleaned.startswith(prefix):
            return f"{prefix}{cleaned}"
        return cleaned

    def attach_skill_prefix_trace(self, tk_var, data_key):
        prefix = self.get_skill_id_prefix(data_key)
        attach_prefix_trace(tk_var, prefix)

    def _init_skill_metadata(self):
        # --- 技能組件參考文件 ---
        self.SKILL_COMPONENT_DOC = textwrap.dedent("""\
# 技能組件完整文檔

本文檔詳細說明遊戲中所有技能效果類型及其參數配置。

## 目錄

- [隊長技能效果 (Leader Skills)](#隊長技能效果-leader-skills)
- [敵人技能效果 (Enemy Skills)](#敵人技能效果-enemy-skills)
- [主動技能效果 (Active Skills)](#主動技能效果-active-skills)
- [參數類型說明](#參數類型說明)
- [元素類型對照表](#元素類型對照表)

---

## 隊長技能效果 (Leader Skills)

隊長技能效果ID以 `LS_` 開頭，配置於 `data/config/leader_skills.json`

### 永久屬性倍率效果 (觸發時機: PERMANENT)

#### HP_MULTIPLIER
**效果**: 提升指定屬性的生命力倍率
**中文描述**: "X屬性生命力 X 倍"
**參數**:
- `target_element` (string): 目標元素 ("FIRE", "WATER", "WOOD", "METAL", "EARTH", "HEART", "ALL")
- `multiplier` (float): 生命力倍率 (例如 1.5)

#### RECOVERY_MULTIPLIER
**效果**: 提升指定屬性的回復力倍率
**中文描述**: "X屬性回復力 X 倍"
**參數**:
- `target_element` (string): 目標元素
- `multiplier` (float): 回復力倍率

#### TEAM_ELEMENT_MULTIPLIER
**效果**: 根據隊伍中指定屬性成員數量提升攻擊倍率
**中文描述**: "隊伍中越多X屬性成員，X屬性傷害越高"
**參數**:
- `target_element` (string): 目標元素
- `base_multiplier` (float): 基礎倍率 (例如 1.0)
- `max_multiplier` (float): 最高倍率 (例如 2.5)
- `per_member_boost` (float): 每位成員增加倍率 (例如 0.3)

#### TEAM_DIVERSITY_MULTIPLIER
**效果**: 根據隊伍屬性多樣性提升全隊攻擊倍率
**中文描述**: "隊伍屬性越多元，攻擊倍率越高"
**參數**:
- `base_multiplier` (float): 基礎倍率
- `max_multiplier` (float): 最高倍率
- `per_unique_boost` (float): 每種屬性增加倍率 (例如 0.2)

#### EXTEND_SLASH_TIME
**效果**: 延長斬擊時間
**中文描述**: "延長斬擊時間 X 秒"
**參數**:
- `extend_seconds` (float): 延長秒數 (例如 2.0)

#### IGNORE_RESISTANCE
**效果**: 無視指定屬性的克制關係
**中文描述**: "X屬性無視屬性克制"
**參數**:
- `target_element` (string): 目標元素

#### ORB_DUAL_EFFECT
**效果**: 指定靈珠兼具另一屬性效果
**中文描述**: "X屬性靈珠兼具Y屬性 Z% 效果"
**參數**:
- `source_element` (string): 來源元素
- `target_element` (string): 目標元素
- `effect_percent` (float): 效果百分比 (例如 50.0)

#### ORB_CAPACITY_BOOST
**效果**: 提升指定屬性靈珠容量上限
**中文描述**: "X屬性靈珠容量 +Y"
**參數**:
- `target_element` (string): 目標元素
- `bonus_capacity` (int): 額外容量 (例如 5)

### 傷害倍率效果 (觸發時機: BEFORE_ATTACK)

#### DAMAGE_MULTIPLIER
**效果**: 提升指定屬性的傷害倍率
**中文描述**: "X屬性傷害 X 倍"
**參數**:
- `target_element` (string): 目標元素
- `multiplier` (float): 傷害倍率

#### BASE_DAMAGE_BOOST
**效果**: 提升指定屬性的基礎傷害百分比
**中文描述**: "X屬性基礎傷害 +Y%"
**參數**:
- `target_element` (string): 目標元素
- `boost_percent` (float): 提升百分比 (例如 30.0)

#### ALL_DAMAGE_BOOST
**效果**: 提升指定屬性的所有傷害類型
**中文描述**: "X屬性全能傷害 +Y%"
**參數**:
- `target_element` (string): 目標元素
- `boost_percent` (float): 提升百分比

#### ORB_COUNT_MULTIPLIER
**效果**: 根據儲存靈珠數量提升傷害倍率
**中文描述**: "X屬性靈珠越多傷害越高"
**參數**:
- `target_element` (string): 目標元素
- `base_multiplier` (float): 基礎倍率 (例如 1.0)
- `max_multiplier` (float): 最高倍率 (例如 3.0)
- `orb_per_tier` (int): 每級所需靈珠數 (例如 3)

### 靈珠規則效果 (觸發時機: TURN_START)

#### FORCE_ORB_SPAWN
**效果**: 固定生成指定數量的元素靈珠
**中文描述**: "前X粒固定出現Y屬性靈珠"
**參數**:
- `target_element` (string): 目標元素
- `count` (int): 靈珠數量

#### ORB_SPAWN_RATE_BOOST
**效果**: 提升指定元素靈珠出現機率
**中文描述**: "X屬性靈珠出現率 +Y%"
**參數**:
- `target_element` (string): 目標元素
- `boost_percent` (float): 提升百分比

#### ORB_DROP_END_TURN
**效果**: 回合結束時掉落靈珠
**中文描述**: "回合結束掉落X屬性靈珠 Y 顆"
**參數**:
- `element` (string): 元素類型
- `count` (int): 掉落數量
- `drop_timing` (string): 掉落時機 ("end_turn" 或 "immediate")

#### ORB_DROP_ON_SLASH
**效果**: 斬擊時掉落靈珠
**中文描述**: "斬擊時掉落X屬性靈珠 Y 顆"
**參數**:
- `element` (string): 元素類型
- `count` (int): 掉落數量

#### SLASH_ORB_SPAWN
**效果**: 斬擊生成靈珠
**中文描述**: "斬擊生成X屬性靈珠 Y 顆"
**參數**:
- `element` (string): 元素類型
- `count` (int): 生成數量

### 回合結束效果 (觸發時機: TURN_END)

#### END_TURN_DAMAGE
**效果**: 回合結束對敵人造成固定傷害
**中文描述**: "回合結束造成X屬性傷害 Y 點"
**參數**:
- `element` (string): 傷害元素
- `damage` (int): 傷害數值

## 敵人技能效果 (Enemy Skills)

敵人技能效果ID以 `ES_` 開頭，配置於 `data/config/enemy_skills.json`

### 條件類效果（阻擋傷害）

#### REQUIRE_COMBO
**效果**: 需要達到指定連擊數才能造成傷害
**中文描述**: "需要X連擊才能造成傷害"
**參數**:
- `required_combo` (int): 需要的連擊數 (例如 10)

#### REQUIRE_ORB_TOTAL
**效果**: 需要消除指定數量的元素靈珠才能造成傷害
**中文描述**: "需要X粒Y屬性靈珠才能造成傷害"
**參數**:
- `required_element` (string): 需要的元素
- `required_count` (int): 需要的數量

#### REQUIRE_ORB_CONTINUOUS
**效果**: 需要連續消除指定數量的元素靈珠
**中文描述**: "需要連續X粒Y屬性靈珠才能造成傷害"
**參數**:
- `required_element` (string): 需要的元素
- `required_count` (int): 連續數量

#### REQUIRE_ELEMENTS
**效果**: 需要消除指定數量的不同元素才能造成傷害
**中文描述**: "需要X種元素才能造成傷害"
**參數**:
- `required_unique_elements` (int): 需要的元素種類數

### 減傷類效果

#### DAMAGE_REDUCTION_PERCENT
**效果**: 減少受到的傷害（百分比）
**中文描述**: "減傷X%"
**參數**:
- `reduction_percent` (float): 減傷百分比 (例如 50.0)

#### DAMAGE_REDUCTION_FLAT
**效果**: 減少受到的傷害（固定值）
**中文描述**: "減傷X點（固定）"
**參數**:
- `reduction_amount` (int): 減傷數值 (例如 100)

### 限制類效果

#### SEAL_ACTIVE_SKILL
**效果**: 封印玩家主動技能
**中文描述**: "封印主動技能X回合"
**參數**:
- `duration` (int): 持續回合數

#### DISABLE_ELEMENT_SLASH
**效果**: 禁用特定元素斬擊
**中文描述**: "禁用X屬性斬擊Y回合"
**參數**:
- `target_element` (string): 目標元素
- `duration` (int): 持續回合數

#### ZERO_RECOVERY
**效果**: 使回復力歸零
**中文描述**: "回復力歸零X回合"
**參數**:
- `duration` (int): 持續回合數

#### REDUCE_SLASH_TIME
**效果**: 減少斬擊時間
**中文描述**: "減少斬擊時間X秒"
**參數**:
- `reduce_seconds` (float): 減少秒數

### 特殊類效果

#### ENTER_HP_TO_ONE
**效果**: 進場時將玩家生命力扣至1
**中文描述**: "進場時生命力扣至1"
**參數**: 無

#### DEATH_DAMAGE
**效果**: 死亡時對玩家造成傷害
**中文描述**: "死亡時造成X點傷害"
**參數**:
- `damage` (int): 傷害數值

#### REVIVE_ONCE
**效果**: 可以復活一次
**中文描述**: "可復活一次"
**參數**: 無

## 主動技能效果 (Active Skills)

主動技能效果ID以 `AS_` 開頭，配置於 `data/config/active_skills.json`

主動技能的 JSON 結構：
```
{
  "skill_id": "AS_EXAMPLE",
  "skill_name": "技能名稱",
  "description": "技能描述",
  "skill_cost": 10,
  "effects": [
    {
      "effect_type": "效果類型",
      "參數名": "參數值"
    }
  ]
}
```

**基本參數說明**:
- `skill_id` (string): 技能唯一ID，以 AS_ 開頭
- `skill_name` (string): 技能名稱
- `description` (string): 技能描述
- `skill_cost` (int): 技能冷卻回合數 (CD)
- `effects` (array): 技能效果列表

## 參數類型說明

### 元素參數 (element / target_element / source_element)
**類型**: string
**可選值**: "FIRE", "WATER", "WOOD", "METAL", "EARTH", "HEART", "ALL"
**說明**: 指定元素類型，"ALL" 表示全部元素

### 倍率參數 (multiplier / base_multiplier / max_multiplier)
**類型**: float
**範圍**: 通常 0.1 ~ 10.0
**說明**: 屬性或傷害的倍率值，1.0 表示100%

### 百分比參數 (boost_percent / reduction_percent / effect_percent)
**類型**: float
**範圍**: 0.0 ~ 100.0
**說明**: 百分比數值，例如 50.0 表示 50%

### 數量參數 (count / damage / required_combo)
**類型**: int
**說明**: 整數數值，表示數量、傷害值、回合數等

### 時機參數 (drop_timing)
**類型**: string
**可選值**: "end_turn", "immediate"
**說明**: 效果觸發時機

## 元素類型對照表

| 英文代碼 | 中文名稱 | Constants 枚舉 |
|---------|---------|---------------|
| FIRE    | 火      | Constants.Element.FIRE |
| WATER   | 水      | Constants.Element.WATER |
| WOOD    | 木      | Constants.Element.WOOD |
| METAL   | 金      | Constants.Element.METAL |
| EARTH   | 土      | Constants.Element.EARTH |
| HEART   | 心      | Constants.Element.HEART |

## 技能配置完整範例

### 隊長技能範例

```
{
  "leader_skills": [
    {
      "skill_id": "LS_FIRE_COMBO",
      "skill_name": "火焰大師",
      "description": "火屬性傷害2倍，生命力1.5倍，回合結束造成500點火傷害",
      "effects": [
        {
          "effect_type": "DAMAGE_MULTIPLIER",
          "target_element": "FIRE",
          "multiplier": 2.0
        },
        {
          "effect_type": "HP_MULTIPLIER",
          "target_element": "FIRE",
          "multiplier": 1.5
        },
        {
          "effect_type": "END_TURN_DAMAGE",
          "element": "FIRE",
          "damage": 500
        }
      ]
    }
  ]
}
```

### 敵人技能範例

```
{
  "enemy_skills": [
    {
      "skill_id": "ES_FIRE_SHIELD",
      "skill_name": "火焰護盾",
      "description": "需要5粒火珠才能造成傷害，減傷50%",
      "effects": [
        {
          "effect_type": "REQUIRE_ORB_TOTAL",
          "required_element": "FIRE",
          "required_count": 5
        },
        {
          "effect_type": "DAMAGE_REDUCTION_PERCENT",
          "reduction_percent": 50.0
        }
      ]
    }
  ]
}
```

---

**文檔版本**: 1.0
**最後更新**: 2025-11-13
**維護者**: Claude Code
""")
        
        # --- 模組化核心：技能效果的 "Schema" (藍圖) ---
        # 根據您的 SKILLS_README.md 和 JSON 檔案定義
        # 格式: "param_name": "widget_type"
        # 類型: int_spin, float_spin, entry, element_combo
        self.ELEMENT_OPTIONS = ['FIRE', 'WATER', 'WOOD', 'METAL', 'EARTH', 'HEART', 'ALL']

        # ==================== 中英文映射 ====================
        # 元素映射
        self.ELEMENT_CN_TO_EN = {
            '火': 'FIRE',
            '水': 'WATER',
            '木': 'WOOD',
            '金': 'METAL',
            '土': 'EARTH',
            '心': 'HEART',
            '全部': 'ALL'
        }
        self.ELEMENT_EN_TO_CN = {v: k for k, v in self.ELEMENT_CN_TO_EN.items()}

        # 稀有度映射
        self.RARITY_CN_TO_EN = {
            '普通': 'COMMON',
            '稀有': 'RARE',
            '史詩': 'EPIC',
            '傳說': 'LEGENDARY'
        }
        self.RARITY_EN_TO_CN = {v: k for k, v in self.RARITY_CN_TO_EN.items()}

        # 種族映射
        self.RACE_CN_TO_EN = {
            '人類': 'HUMAN',
            '精靈': 'ELF',
            '神族': 'DWARF',
            '獸類': 'ORC',
            '魔族': 'DEMON',
            '保留': 'UNDEAD',
            '龍族': 'DRAGON',
            '保留': 'ELEMENTAL'
        }
        self.RACE_EN_TO_CN = {v: k for k, v in self.RACE_CN_TO_EN.items()}

        # 目標類型映射
        self.TARGET_CN_TO_EN = {
            '自己': 'SELF',
            '所有隊友': 'ALL_ALLIES',
            '單一敵人': 'SINGLE_ENEMY',
            '所有敵人': 'ALL_ENEMIES',
            '隨機敵人': 'RANDOM_ENEMY'
        }
        self.TARGET_EN_TO_CN = {v: k for k, v in self.TARGET_CN_TO_EN.items()}

        self.SKILL_EFFECT_SCHEMA = {
            # --- 我方 (Active / Leader) ---
            "HP_MULTIPLIER": [
                ("target_element", "element_combo", "目標元素"),
                ("multiplier", "float_spin", "生命力倍率 (例如 1.5)")
            ],
            "RECOVERY_MULTIPLIER": [
                ("target_element", "element_combo", "目標元素"),
                ("multiplier", "float_spin", "回復力倍率 (例如 2.0)")
            ],
            "TEAM_ELEMENT_MULTIPLIER": [
                ("target_element", "element_combo", "指定隊伍屬性"),
                ("base_multiplier", "float_spin", "基礎倍率"),
                ("max_multiplier", "float_spin", "最高倍率"),
                ("per_member_boost", "float_spin", "每位成員提升量")
            ],
            "TEAM_DIVERSITY_MULTIPLIER": [
                ("base_multiplier", "float_spin", "基礎倍率"),
                ("max_multiplier", "float_spin", "最高倍率"),
                ("per_unique_boost", "float_spin", "每種屬性提升")
            ],
            "EXTEND_SLASH_TIME": [("extend_seconds", "float_spin", "延長秒數")],
            "IGNORE_RESISTANCE": [("target_element", "element_combo", "要無視克制的元素")],
            "ORB_DUAL_EFFECT": [
                ("source_element", "element_combo", "來源靈珠"),
                ("target_element", "element_combo", "兼具的屬性"),
                ("effect_percent", "float_spin", "兼具百分比 (0-100)")
            ],
            "ORB_CAPACITY_BOOST": [
                ("target_element", "element_combo", "目標元素"),
                ("bonus_capacity", "int_spin", "額外容量")
            ],
            "DAMAGE_MULTIPLIER": [
                ("target_element", "element_combo", "目標元素"),
                ("multiplier", "float_spin", "傷害倍率 (例如 2.0)")
            ],
            "BASE_DAMAGE_BOOST": [
                ("target_element", "element_combo", "目標元素"),
                ("boost_percent", "float_spin", "提升百分比")
            ],
            "ALL_DAMAGE_BOOST": [
                ("target_element", "element_combo", "目標元素"),
                ("boost_percent", "float_spin", "提升百分比")
            ],
            "ORB_COUNT_MULTIPLIER": [
                ("target_element", "element_combo", "目標元素"),
                ("base_multiplier", "float_spin", "基礎倍率"),
                ("max_multiplier", "float_spin", "最高倍率"),
                ("orb_per_tier", "int_spin", "每級所需靈珠")
            ],
            "FORCE_ORB_SPAWN": [
                ("target_element", "element_combo", "要生成的屬性"),
                ("count", "int_spin", "生成數量")
            ],
            "ORB_SPAWN_RATE_BOOST": [
                ("target_element", "element_combo", "目標元素"),
                ("boost_percent", "float_spin", "提升百分比")
            ],
            "ORB_DROP_END_TURN": [
                ("element", "element_combo", "掉落屬性"),
                ("count", "int_spin", "掉落數量"),
                ("drop_timing", "entry", "觸發時機 (end_turn / immediate)")
            ],
            "ORB_DROP_ON_SLASH": [
                ("slash_element", "element_combo", "斬擊的元素類型"),
                ("drop_element", "element_combo", "掉落的元素類型（可選，默認與slash_element相同）"),
                ("count", "int_spin", "掉落數量"),
                ("chance_percent", "float_spin", "掉落機率百分比（可選，默認100.0）")
            ],
            "SLASH_ORB_SPAWN": [
                ("slash_element", "element_combo", "斬擊的元素類型"),
                ("spawn_element", "element_combo", "生成的元素類型（可選，默認與slash_element相同）"),
                ("required_count", "int_spin", "累積所需數量（默認3）"),
                ("spawn_count", "int_spin", "生成數量（默認1）")
            ],
            "END_TURN_DAMAGE": [
                ("element", "element_combo", "傷害屬性"),
                ("damage", "int_spin", "固定傷害")
            ],
            # 其他沿用的自訂效果
            "ELEMENT_DAMAGE_BOOST": [("element", "element_combo", "目標元素"), ("boost_percent", "float_spin", "傷害提升百分比")],
            "HEAL_MULTIPLIER": [("multiplier", "float_spin", "回復力倍率")],
            "IGNORE_ENEMY_SKILL": [
                ("target_skill_id", "entry", "要無視的敵人技能ID (可選，留空則無視所有)"),
                ("target_scope", "combo", "影響範圍 (SELF/ALL_ALLIES)")
            ],
            "DAMAGE_REDUCTION": [
                ("reduction_percent", "float_spin", "減傷百分比"),
                ("target_scope", "combo", "影響範圍 (SELF/ALL_ALLIES)")
            ],
            "COMBO_BOOST": [
                ("combo_bonus", "int_spin", "額外 Combo"),
                ("target_scope", "combo", "影響範圍 (SELF/ALL_ALLIES)")
            ],
            # ✅ 新增：基礎數值提升 (修改卡片base_atk/base_hp/base_recovery)
            "BASE_STAT_BOOST": [
                ("target_scope", "combo", "影響範圍 (SELF/ALL_ALLIES)"),
                ("target_element", "element_combo", "目標元素 (可選)"),
                ("target_rarity", "combo", "目標稀有度 (可選：R/SR/SSR)"),
                ("target_card_ids", "entry", "特定卡片ID列表 (可選，JSON格式：[\"ID002\"])"),
                ("target_stat", "combo", "目標屬性 (base_atk/base_hp/base_recovery)"),
                ("boost_percent", "float_spin", "提升百分比")
            ],
            # ✅ 新增：最終傷害倍率 (在傷害計算最後階段生效)
            "FINAL_DAMAGE_MULTIPLIER": [
                ("target_scope", "combo", "影響範圍 (SELF/ALL_ALLIES)"),
                ("target_element", "element_combo", "目標元素 (可選)"),
                ("multiplier", "float_spin", "最終傷害倍率 (例如 2.0)")
            ],
            "REMOVE_RANDOM_ORBS": [
                ("target_element", "element_combo", "移除屬性"),
                ("count", "int_spin", "移除數量")
            ],

            # --- 敵方 (Enemy) ---
            "REQUIRE_COMBO": [("required_combo", "int_spin", "需要的連擊數")],
            "REQUIRE_COMBO_EXACT": [("required_combo", "int_spin", "需要的連擊數（完全相等）")],
            "REQUIRE_COMBO_MAX": [("max_combo", "int_spin", "最大允許連擊數")],
            "REQUIRE_ORB_TOTAL": [
                ("required_element", "element_combo", "檢查的屬性"),
                ("required_count", "int_spin", "需要的數量")
            ],
            "REQUIRE_ORB_CONTINUOUS": [
                ("required_element", "element_combo", "檢查的屬性"),
                ("required_count", "int_spin", "連續數量")
            ],
            "REQUIRE_ELEMENTS": [("required_unique_elements", "int_spin", "元素種類數")],
            "REQUIRE_ENEMY_ATTACK": [],
            "REQUIRE_STORED_ORB_MIN": [("requirements", "entry", "JSON 數組：[{\"element\":\"FIRE\",\"count\":3}]")],
            "REQUIRE_STORED_ORB_EXACT": [("requirements", "entry", "JSON 數組：[{\"element\":\"FIRE\",\"count\":3}]")],
            "DAMAGE_ONCE_ONLY": [],
            "DAMAGE_REDUCTION_PERCENT": [("reduction_percent", "float_spin", "減傷百分比")],
            "DAMAGE_REDUCTION_FLAT": [("reduction_amount", "int_spin", "固定減傷")],
            "SEAL_ACTIVE_SKILL": [("duration", "int_spin", "封印回合")],
            "DISABLE_ELEMENT_SLASH": [
                ("target_element", "element_combo", "禁用屬性"),
                ("duration", "int_spin", "持續回合")
            ],
            "ZERO_RECOVERY": [("duration", "int_spin", "持續回合")],
            "REDUCE_SLASH_TIME": [("reduce_seconds", "float_spin", "減少秒數")],
            "ENTER_HP_TO_ONE": [],
            "DEATH_DAMAGE": [("damage", "int_spin", "死亡時傷害")],
            "REVIVE_ONCE": [],
            "COMBO_SHIELD_DAMAGE_REDUCTION": []
        }
        self.EFFECT_TYPE_DESCRIPTIONS = {
            # --- 我方 (Active / Leader) ---
            "HP_MULTIPLIER": "X屬性生命力 X 倍",
            "RECOVERY_MULTIPLIER": "X屬性回復力 X 倍",
            "TEAM_ELEMENT_MULTIPLIER": "隊伍中越多指定屬性成員，該屬性倍率越高",
            "TEAM_DIVERSITY_MULTIPLIER": "隊伍屬性越多元，全隊倍率越高",
            "EXTEND_SLASH_TIME": "延長斬擊時間 X 秒",
            "IGNORE_RESISTANCE": "指定屬性攻擊無視克制",
            "ORB_DUAL_EFFECT": "X屬性靈珠兼具Y屬性 Z% 效果",
            "ORB_CAPACITY_BOOST": "指定屬性的靈珠容量 +Y",
            "DAMAGE_MULTIPLIER": "X屬性傷害 X 倍",
            "BASE_DAMAGE_BOOST": "X屬性基礎傷害 +Y%",
            "ALL_DAMAGE_BOOST": "X屬性所有傷害 +Y%",
            "ORB_COUNT_MULTIPLIER": "儲存的靈珠越多，倍率越高",
            "FORCE_ORB_SPAWN": "前X粒固定出現指定屬性靈珠",
            "ORB_SPAWN_RATE_BOOST": "指定屬性靈珠出現率 +Y%",
            "ORB_DROP_END_TURN": "回合結束掉落指定屬性的靈珠",
            "ORB_DROP_ON_SLASH": "斬擊X屬性時有Y%機率掉落Z顆A屬性靈珠",
            "SLASH_ORB_SPAWN": "斬擊X屬性累積Y粒後立刻生成Z顆A屬性靈珠",
            "END_TURN_DAMAGE": "回合結束造成指定屬性固定傷害",
            "ELEMENT_DAMAGE_BOOST": "X回合內Y屬性傷害提升Z%",
            "HEAL_MULTIPLIER": "回復類效果倍率",
            "IGNORE_ENEMY_SKILL": "無視指定敵人技能 (可指定技能ID或無視所有)",
            "DAMAGE_REDUCTION": "減少所受傷害 (百分比)，支援SELF/ALL_ALLIES",
            "COMBO_BOOST": "額外增加連擊數，支援SELF/ALL_ALLIES",
            # ✅ 新增：基礎數值提升說明
            "BASE_STAT_BOOST": "立即修改卡片基礎屬性 (base_atk/base_hp/base_recovery)，卡面數值即時更新，BUFF結束後自動恢復原值。支援元素/稀有度/特定卡片ID篩選。",
            # ✅ 新增：最終傷害倍率說明
            "FINAL_DAMAGE_MULTIPLIER": "在傷害計算最後階段生效的倍率，不修改卡面數值。與現有DAMAGE_MULTIPLIER向後兼容。",
            "REMOVE_RANDOM_ORBS": "移除隨機指定屬性的靈珠",

            # --- 敵方 (Enemy) ---
            "REQUIRE_COMBO": "需要達到X連擊才能造成傷害",
            "REQUIRE_COMBO_EXACT": "須保持連擊數 = X 連擊才可造成傷害",
            "REQUIRE_COMBO_MAX": "連擊數不可高於 X 連擊，否則無法造成傷害",
            "REQUIRE_ORB_TOTAL": "需要累積指定數量的某屬性靈珠",
            "REQUIRE_ORB_CONTINUOUS": "需要連續消除指定數量的靈珠",
            "REQUIRE_ELEMENTS": "需要至少X種不同元素",
            "REQUIRE_ENEMY_ATTACK": "敵人必須先攻擊後，否則無法造成傷害（條件可繼承回合）",
            "REQUIRE_STORED_ORB_MIN": "儲存X屬性靈珠必須達到Y個（含以上）才可造成傷害（支持多元素）",
            "REQUIRE_STORED_ORB_EXACT": "儲存X屬性靈珠必須達到Y個（完全一樣）才可造成傷害（支持多元素）",
            "DAMAGE_ONCE_ONLY": "敵人只會被攻擊一次，第二次以後無法造成傷害",
            "DAMAGE_REDUCTION_PERCENT": "受到傷害降低 X%",
            "DAMAGE_REDUCTION_FLAT": "每次攻擊減傷固定值",
            "SEAL_ACTIVE_SKILL": "封印主動技能 X 回合",
            "DISABLE_ELEMENT_SLASH": "禁用某屬性的斬擊 X 回合",
            "ZERO_RECOVERY": "回復力歸零 X 回合",
            "REDUCE_SLASH_TIME": "斬擊時間減少 X 秒",
            "ENTER_HP_TO_ONE": "進場時玩家生命降至 1",
            "DEATH_DAMAGE": "死亡時對玩家造成傷害",
            "REVIVE_ONCE": "死亡後可復活一次",
            "COMBO_SHIELD_DAMAGE_REDUCTION": "連擊盾附加減傷"
        }
        
        # 定義敵方專屬技能前綴/關鍵字（更完整的列表）
        enemy_skill_keywords = [
            "REQUIRE_", "DAMAGE_REDUCTION_", "SEAL_", "DISABLE_",
            "ZERO_", "REDUCE_SLASH_TIME", "ENTER_HP_TO_ONE",
            "DEATH_DAMAGE", "REVIVE_", "COMBO_SHIELD", "DAMAGE_ONCE_ONLY"
        ]

        # 判斷是否為敵方技能
        def is_enemy_skill(effect_type):
            return any(effect_type.startswith(keyword) or effect_type == keyword
                      for keyword in enemy_skill_keywords)

        # 建立所有 effect_type 的列表
        self.ALL_PLAYER_EFFECT_TYPES = sorted(list(set(
            [s['effect_type'] for s in self.data_cache.get('active_skills', {}).get('active_skills', []) for s in s['effects']] +
            [s['effect_type'] for s in self.data_cache.get('leader_skills', {}).get('leader_skills', []) for s in s['effects']] +
            [k for k in self.SKILL_EFFECT_SCHEMA.keys() if not is_enemy_skill(k)]
        )))
        self.ALL_ENEMY_EFFECT_TYPES = sorted(list(set(
            [s['effect_type'] for s in self.data_cache.get('enemy_skills', {}).get('enemy_skills', []) for s in s['effects']] +
            [k for k in self.SKILL_EFFECT_SCHEMA.keys() if is_enemy_skill(k)]
        )))


    def _build_base_ui(self):
        self.create_menu()
        self.create_status_bar()
        self.notebook = ttk.Notebook(self.root)

        self.tab_player_cards = ttk.Frame(self.notebook)
        self.tab_enemy_cards = ttk.Frame(self.notebook)
        self.tab_player_skills = ttk.Frame(self.notebook)
        self.tab_enemy_skills = ttk.Frame(self.notebook)
        self.tab_stages = ttk.Frame(self.notebook)  # 關卡管理標籤
        self.tab_regions = ttk.Frame(self.notebook)  # 區域管理標籤
        self.tab_shop_items = ttk.Frame(self.notebook)  # 商城系統標籤
        self.tab_gacha_pools = ttk.Frame(self.notebook)  # 抽卡系統標籤
        self.tab_training_rooms = ttk.Frame(self.notebook)  # 訓練室標籤

        self.notebook.add(self.tab_player_cards, text='我方卡片', state="disabled")
        self.notebook.add(self.tab_enemy_cards, text='敵方卡片', state="disabled")
        self.notebook.add(self.tab_player_skills, text='我方技能', state="disabled")
        self.notebook.add(self.tab_enemy_skills, text='敵方技能', state="disabled")
        self.notebook.add(self.tab_stages, text='關卡管理', state="disabled")  # 新增關卡管理標籤
        self.notebook.add(self.tab_regions, text='區域管理', state="disabled")  # 新增區域管理標籤
        self.notebook.add(self.tab_shop_items, text='商城系統', state="disabled")  # 新增商城系統標籤
        self.notebook.add(self.tab_gacha_pools, text='抽卡系統', state="disabled")  # 新增抽卡系統標籤
        self.notebook.add(self.tab_training_rooms, text='訓練室', state="disabled")  # 新增訓練室標籤

        self.notebook.pack(expand=True, fill='both', padx=10, pady=10)
        self.notebook.pack_forget()

        # ✅ 綁定分頁切換事件 - 切換前自動儲存
        self.notebook.bind('<<NotebookTabChanged>>', self.on_tab_changed)

        self.placeholder_label = ttk.Label(
            self.root,
            text="歡迎使用編輯器。\n\n請從上方工作列 [檔案] -> [設定 data 資料夾...]\n\n來載入您的遊戲專案。",
            font=("Arial", 14),
            justify=tk.CENTER
        )
        self.placeholder_label.pack(expand=True, fill='both', padx=20, pady=20)

    # --- 1. 工作列 / 狀態列 (相同) ---
    def create_menu(self):
        menu_bar = tk.Menu(self.root)
        file_menu = tk.Menu(menu_bar, tearoff=0)
        file_menu.add_command(label="設定 data 資料夾...", command=self.select_data_directory)
        file_menu.add_separator()
        file_menu.add_command(label="退出", command=self.root.quit)
        menu_bar.add_cascade(label="檔案", menu=file_menu)

        help_menu = tk.Menu(menu_bar, tearoff=0)
        help_menu.add_command(label="技能組件文檔", command=self.open_skill_documentation_window)
        menu_bar.add_cascade(label="說明", menu=help_menu)
        self.root.config(menu=menu_bar)

    def create_status_bar(self):
        self.status_var = tk.StringVar()
        self.status_var.set("準備就緒。請從 [檔案] 選單載入資料夾。")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief=tk.SUNKEN, anchor='w', padding=(5, 2))
        status_bar.pack(side=tk.BOTTOM, fill='x')

    def open_skill_documentation_window(self):
        doc_window = tk.Toplevel(self.root)
        doc_window.title("技能組件文檔")
        doc_window.geometry("900x700")

        container = ttk.Frame(doc_window)
        container.pack(fill='both', expand=True)

        scrollbar = ttk.Scrollbar(container)
        scrollbar.pack(side=tk.RIGHT, fill='y')

        text_widget = tk.Text(container, wrap='word', yscrollcommand=scrollbar.set)
        text_widget.insert(tk.END, self.SKILL_COMPONENT_DOC)
        text_widget.config(state='disabled')
        text_widget.pack(side=tk.LEFT, fill='both', expand=True)
        scrollbar.config(command=text_widget.yview)

    # --- 2. 資料載入 (相同) ---
    def select_data_directory(self):
        path = filedialog.askdirectory(title="請選擇您的 'data' 資料夾")
        if not path:
            self.status_var.set("已取消選擇。")
            return

        missing_files = []
        for key, file_rel_path in self.FILE_PATHS.items():
            full_path = os.path.join(path, file_rel_path)
            if not os.path.exists(full_path):
                missing_files.append(file_rel_path)
        
        if missing_files:
            messagebox.showerror("錯誤", f"路徑無效。\n\n在 {path} 中找不到以下檔案:\n" + "\n".join(missing_files) + "\n\n請確認您選擇的是 'data' 資料夾。")
            self.status_var.set("載入失敗。請重新選擇資料夾。")
            return

        self.data_path = path
        self.status_var.set(f"資料夾載入成功: {self.data_path}")
        self.placeholder_label.pack_forget()
        self.notebook.pack(expand=True, fill='both', padx=10, pady=10)
        self.load_and_populate_all_tabs()
        self._start_auto_refresh()

    def load_and_populate_all_tabs(self):
        self.data_cache = {}
        try:
            for key, file_rel_path in self.FILE_PATHS.items():
                full_path = os.path.join(self.data_path, file_rel_path)
                if os.path.exists(full_path):
                    with open(full_path, 'r', encoding='utf-8') as f:
                        self.data_cache[key] = json.load(f)
            
            # (重新) 產生效果類型列表（使用統一的分類邏輯）
            enemy_skill_keywords = [
                "REQUIRE_", "DAMAGE_REDUCTION_", "SEAL_", "DISABLE_",
                "ZERO_", "REDUCE_SLASH_TIME", "ENTER_HP_TO_ONE",
                "DEATH_DAMAGE", "REVIVE_", "COMBO_SHIELD", "DAMAGE_ONCE_ONLY"
            ]

            def is_enemy_skill(effect_type):
                return any(effect_type.startswith(keyword) or effect_type == keyword
                          for keyword in enemy_skill_keywords)

            self.ALL_PLAYER_EFFECT_TYPES = sorted(list(set(
                [s['effect_type'] for s in self.data_cache.get('active_skills', {}).get('active_skills', []) for s in s['effects']] +
                [s['effect_type'] for s in self.data_cache.get('leader_skills', {}).get('leader_skills', []) for s in s['effects']] +
                [k for k in self.SKILL_EFFECT_SCHEMA.keys() if not is_enemy_skill(k)]
            )))
            self.ALL_ENEMY_EFFECT_TYPES = sorted(list(set(
                [s['effect_type'] for s in self.data_cache.get('enemy_skills', {}).get('enemy_skills', []) for s in s['effects']] +
                [k for k in self.SKILL_EFFECT_SCHEMA.keys() if is_enemy_skill(k)]
            )))

        except Exception as e:
            messagebox.showerror("JSON 讀取錯誤", f"讀取 JSON 檔案時發生錯誤: {e}")
            self.status_var.set("JSON 讀取錯誤，請檢查檔案格式。")
            return

        # 啟用所有分頁
        if self.data_cache.get("cards"):
            self.notebook.tab(self.tab_player_cards, state="normal")
            self.populate_player_cards_tab()
        if self.data_cache.get("enemies"):
            self.notebook.tab(self.tab_enemy_cards, state="normal")
            self.populate_enemy_cards_tab()
        if self.data_cache.get("active_skills") or self.data_cache.get("leader_skills"):
            self.notebook.tab(self.tab_player_skills, state="normal")
            self.populate_player_skills_tab()
        if self.data_cache.get("enemy_skills"):
            self.notebook.tab(self.tab_enemy_skills, state="normal")
            self.populate_enemy_skills_tab()
        if self.data_cache.get("stages"):
            self.notebook.tab(self.tab_stages, state="normal")
            self.populate_stages_tab()
        if self.data_cache.get("regions"):
            self.notebook.tab(self.tab_regions, state="normal")
            self.populate_regions_tab()
        if self.data_cache.get("shop_items"):
            self.notebook.tab(self.tab_shop_items, state="normal")
            self.populate_shop_items_tab()
        if self.data_cache.get("gacha_pools"):
            self.notebook.tab(self.tab_gacha_pools, state="normal")
            self.populate_gacha_pools_tab()
        if self.data_cache.get("training_rooms"):
            self.notebook.tab(self.tab_training_rooms, state="normal")
            self.populate_training_rooms_tab()

        self._update_data_snapshot()
        self.status_var.set("編輯器準備就緒。")

    def _get_data_file_snapshot(self):
        if not self.data_path:
            return {}
        snapshot = {}
        for file_rel_path in self.FILE_PATHS.values():
            full_path = os.path.join(self.data_path, file_rel_path)
            snapshot[full_path] = os.path.getmtime(full_path) if os.path.exists(full_path) else None
        return snapshot

    def _update_data_snapshot(self):
        self._data_file_snapshot = self._get_data_file_snapshot()

    def _start_auto_refresh(self):
        if self._auto_refresh_job:
            self.root.after_cancel(self._auto_refresh_job)
        self._update_data_snapshot()
        self._auto_refresh_job = self.root.after(self.auto_refresh_interval_ms, self._poll_data_directory)

    def _poll_data_directory(self):
        if not self.data_path:
            return
        current_snapshot = self._get_data_file_snapshot()
        if self._data_file_snapshot and current_snapshot != self._data_file_snapshot:
            self.load_and_populate_all_tabs()
            self.status_var.set("偵測到資料夾變更，已自動重新整理。")
        self._auto_refresh_job = self.root.after(self.auto_refresh_interval_ms, self._poll_data_directory)

    # --- 3. 儲存功能 (相同) ---
    def save_data_to_file(self, data_key):
        if not self.data_path or data_key not in self.data_cache:
            self.status_var.set(f"儲存失敗：找不到資料 {data_key}")
            return
            
        full_path = os.path.join(self.data_path, self.FILE_PATHS[data_key])
        
        try:
            with open(full_path, 'w', encoding='utf-8') as f:
                json.dump(self.data_cache[data_key], f, indent=4, ensure_ascii=False)
            self.status_var.set(f"儲存成功！ {self.FILE_PATHS[data_key]} 已更新。")
            self._update_data_snapshot()
        except Exception as e:
            messagebox.showerror("儲存錯誤", f"寫入 {full_path} 時發生錯誤: {e}")
            self.status_var.set(f"儲存失敗: {e}")

    def clear_tab(self, tab_frame):
        """輔助函數：清除分頁中的所有舊元件"""
        for widget in tab_frame.winfo_children():
            widget.destroy()

    # --- 4. "我方卡片" 分頁 (v0.3 功能) ---
    # (此處代碼與 v0.3 完全相同，僅折疊)
    def populate_player_cards_tab(self):
        self.clear_tab(self.tab_player_cards)
        cards_data = self.data_cache.get('cards')
        if not cards_data or 'cards' not in cards_data:
            ttk.Label(self.tab_player_cards, text="cards.json 格式錯誤或為空").pack()
            return

        left_frame = ttk.Frame(self.tab_player_cards, width=250)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        # 新增/刪除 按鈕
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x')
        ttk.Button(btn_frame, text="新增卡片", command=self.add_new_player_card).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(btn_frame, text="刪除選定", command=self.delete_current_player_card).pack(side=tk.LEFT, expand=True, fill='x')

        self.player_card_listbox = tk.Listbox(left_frame, exportselection=False)
        self.player_card_listbox.pack(fill=tk.BOTH, expand=True)

        for i, card in enumerate(cards_data['cards']):
            self.player_card_listbox.insert(tk.END, f"{card.get('card_id', '???')} - {card.get('card_name', 'N/A')}")
        
        self.player_card_listbox.bind('<<ListboxSelect>>', self.on_player_card_selected)
        
        self.player_card_detail_frame = ttk.Frame(self.tab_player_cards)
        self.player_card_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.player_card_detail_frame, text="請從左側列表選擇一張卡片進行編輯").pack(padx=20, pady=20)

    def on_player_card_selected(self, event):
        # ✅ 自動儲存：在切換卡片前，先儲存當前卡片的修改
        if hasattr(self, 'current_selected_card_id') and self.current_selected_card_id and self.widget_vars:
            try:
                self.auto_save_current_player_card()
            except Exception as e:
                print(f"⚠️ 自動儲存失敗: {e}")

        if not self.player_card_listbox.curselection():
            return

        selected_index = self.player_card_listbox.curselection()[0]
        selected_card_data = self.data_cache['cards']['cards'][selected_index]
        self.current_selected_card_id = selected_card_data.get('card_id')

        self.clear_tab(self.player_card_detail_frame)
        self.widget_vars = {} 

        canvas = tk.Canvas(self.player_card_detail_frame)
        scrollbar = ttk.Scrollbar(self.player_card_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # ✅ 綁定鼠標滾輪
        self.bind_mousewheel(canvas)

        def create_form_row(parent, label, widget_type, data_key, options=None):
            row_frame = ttk.Frame(parent); row_frame.pack(fill='x', pady=2)
            ttk.Label(row_frame, text=label, width=15).pack(side=tk.LEFT)
            data_value = selected_card_data.get(data_key)
            if widget_type == 'label':
                var = tk.StringVar(value=data_value); ttk.Label(row_frame, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            elif widget_type == 'entry':
                var = tk.StringVar(value=data_value); widget = ttk.Entry(row_frame, textvariable=var); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(data_value or 0)); widget = ttk.Spinbox(row_frame, from_=0, to=9999, textvariable=var); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'combobox':
                var = tk.StringVar(value=data_value); widget = ttk.Combobox(row_frame, textvariable=var, values=options, state='readonly'); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'element_combobox':
                # 元素選擇器（顯示中文，存儲英文）
                current_en = data_value or ""
                current_cn = self.ELEMENT_EN_TO_CN.get(current_en, "")
                display_var = tk.StringVar(value=current_cn)
                cn_options = [self.ELEMENT_EN_TO_CN.get(e, e) for e in self.ELEMENT_OPTIONS]
                widget = ttk.Combobox(row_frame, textvariable=display_var, values=cn_options, state='readonly')
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                en_var = tk.StringVar(value=current_en)
                self.widget_vars[data_key] = en_var
                def on_change(event, dv=display_var, ev=en_var):
                    ev.set(self.ELEMENT_CN_TO_EN.get(dv.get(), ""))
                widget.bind('<<ComboboxSelected>>', on_change)
            elif widget_type == 'rarity_combobox':
                # 稀有度選擇器（顯示中文，存儲英文）
                current_en = data_value or "COMMON"
                current_cn = self.RARITY_EN_TO_CN.get(current_en, "")
                display_var = tk.StringVar(value=current_cn)
                cn_options = list(self.RARITY_CN_TO_EN.keys())
                widget = ttk.Combobox(row_frame, textvariable=display_var, values=cn_options, state='readonly')
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                en_var = tk.StringVar(value=current_en)
                self.widget_vars[data_key] = en_var
                def on_change(event, dv=display_var, ev=en_var):
                    ev.set(self.RARITY_CN_TO_EN.get(dv.get(), "COMMON"))
                widget.bind('<<ComboboxSelected>>', on_change)
            elif widget_type == 'race_combobox':
                # 種族選擇器（顯示中文，存儲英文）
                current_en = data_value or "HUMAN"
                current_cn = self.RACE_EN_TO_CN.get(current_en, "")
                display_var = tk.StringVar(value=current_cn)
                cn_options = list(self.RACE_CN_TO_EN.keys())
                widget = ttk.Combobox(row_frame, textvariable=display_var, values=cn_options, state='readonly')
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                en_var = tk.StringVar(value=current_en)
                self.widget_vars[data_key] = en_var
                def on_change(event, dv=display_var, ev=en_var):
                    ev.set(self.RACE_CN_TO_EN.get(dv.get(), "HUMAN"))
                widget.bind('<<ComboboxSelected>>', on_change)
            elif widget_type == 'dynamic_combobox':
                # 創建一個容器來包含下拉選單和按鈕
                combo_container = ttk.Frame(row_frame)
                combo_container.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

                # 準備技能數據和映射
                skill_data = self.data_cache.get(options['data_key'])
                skill_list = skill_data.get(options['list_key'], [])

                # 建立 skill_id -> skill_name 的映射和顯示選項
                skill_id_to_name = {}
                skill_name_to_id = {}
                display_options = [""]

                for s in skill_list:
                    skill_id = s.get(options['id_key'], 'N/A')
                    skill_name = s.get(options.get('name_key', 'skill_name'), 'N/A')
                    display_text = f"{skill_name} ({skill_id})"
                    skill_id_to_name[skill_id] = display_text
                    skill_name_to_id[display_text] = skill_id
                    display_options.append(display_text)

                # 下拉選單 - 顯示技能名稱，但內部存儲 skill_id
                current_id = data_value
                current_display = skill_id_to_name.get(current_id, current_id if current_id else "")

                display_var = tk.StringVar(value=current_display)
                widget = ttk.Combobox(combo_container, textvariable=display_var, values=display_options, state='readonly')
                widget.pack(side=tk.LEFT, fill='x', expand=True)

                # 創建一個隱藏的變量來存儲實際的 skill_id
                id_var = tk.StringVar(value=current_id)
                self.widget_vars[data_key] = id_var

                # 當選擇改變時，更新 id_var
                def on_combo_change(event):
                    selected_display = display_var.get()
                    actual_id = skill_name_to_id.get(selected_display, "")
                    id_var.set(actual_id)

                widget.bind('<<ComboboxSelected>>', on_combo_change)

                # 按鈕區域
                btn_container = ttk.Frame(combo_container)
                btn_container.pack(side=tk.LEFT, padx=(5, 0))

                # 新增技能按鈕
                def create_new_skill():
                    self.notebook.select(self.tab_player_skills)
                    messagebox.showinfo("提示", "請在「我方技能」標籤頁中點擊「新增技能」按鈕來創建新技能")

                # 編輯技能按鈕
                def edit_selected_skill():
                    skill_id = id_var.get()
                    if not skill_id or skill_id == "":
                        messagebox.showwarning("警告", "請先選擇一個技能")
                        return

                    # 切換到我方技能標籤頁
                    self.notebook.select(self.tab_player_skills)

                    # 等待標籤頁更新
                    self.root.update_idletasks()

                    # 切換到主動技能子標籤頁
                    if hasattr(self, 'tab_active_skills'):
                        # 找到子 notebook
                        for child in self.tab_player_skills.winfo_children():
                            if isinstance(child, ttk.Notebook):
                                child.select(self.tab_active_skills)
                                break

                        # 在主動技能的 listbox 中選中該技能
                        if hasattr(self, 'active_skills_listbox'):
                            listbox = self.active_skills_listbox
                            skill_data_root = self.data_cache.get('active_skills')
                            skills = skill_data_root.get('active_skills', [])

                            # 找到技能在列表中的索引
                            for idx, skill in enumerate(skills):
                                if skill.get('skill_id') == skill_id:
                                    listbox.selection_clear(0, tk.END)
                                    listbox.select_set(idx)
                                    listbox.see(idx)
                                    listbox.event_generate('<<ListboxSelect>>')
                                    break

                ttk.Button(btn_container, text="新增", width=6, command=create_new_skill).pack(side=tk.LEFT, padx=2)
                ttk.Button(btn_container, text="編輯", width=6, command=edit_selected_skill).pack(side=tk.LEFT)
            elif widget_type == 'dynamic_listbox':
                list_frame = ttk.Frame(row_frame); list_frame.pack(side=tk.LEFT, fill='x', expand=True, padx=5); listbox = tk.Listbox(list_frame, height=4, exportselection=False);
                if data_value:
                    for item in data_value: listbox.insert(tk.END, item)
                listbox.pack(side=tk.LEFT, fill='x', expand=True);
                btn_frame = ttk.Frame(list_frame); btn_frame.pack(side=tk.LEFT, padx=5)

                add_cmd = partial(self.add_skill_to_listbox, listbox, options)
                remove_cmd = partial(self.remove_skill_from_listbox, listbox)
                ttk.Button(btn_frame, text="加入既有", command=add_cmd).pack(pady=2, fill='x')
                ttk.Button(btn_frame, text="移除", command=remove_cmd).pack(pady=2, fill='x')

                effect_types = options.get('effect_types')
                if effect_types is None:
                    effect_types = self.ALL_ENEMY_EFFECT_TYPES if options.get('data_key') == 'enemy_skills' else self.ALL_PLAYER_EFFECT_TYPES

                allow_inline = options.get('allow_inline_edit', True)

                def on_new_skill_created(saved_skill):
                    new_id = saved_skill.get(options['id_key'])
                    if new_id and new_id not in listbox.get(0, tk.END):
                        listbox.insert(tk.END, new_id)
                        listbox.selection_clear(0, tk.END)
                        listbox.select_set(tk.END)

                def create_new_skill_inline():
                    self.open_skill_editor_dialog(
                        data_key=options['data_key'],
                        list_key=options['list_key'],
                        id_key=options['id_key'],
                        name_key=options.get('name_key', options['id_key']),
                        effect_types=effect_types,
                        on_created=on_new_skill_created
                    )

                def edit_selected_skill_inline():
                    if not listbox.curselection():
                        messagebox.showerror("錯誤", "請先選擇列表中的技能", parent=self.root)
                        return
                    selected_skill_id = listbox.get(listbox.curselection()[0])
                    skill_ref = self.find_skill_record(options['data_key'], options['list_key'], options['id_key'], selected_skill_id)
                    if not skill_ref:
                        messagebox.showerror("錯誤", f"在 {options['data_key']} 中找不到 {selected_skill_id}", parent=self.root)
                        return
                    self.open_skill_editor_dialog(
                        data_key=options['data_key'],
                        list_key=options['list_key'],
                        id_key=options['id_key'],
                        name_key=options.get('name_key', options['id_key']),
                        effect_types=effect_types,
                        skill_ref=skill_ref
                    )

                if allow_inline:
                    ttk.Button(btn_frame, text="創建技能", command=create_new_skill_inline).pack(pady=2, fill='x')
                    ttk.Button(btn_frame, text="編輯技能", command=edit_selected_skill_inline).pack(pady=2, fill='x')

                self.widget_vars[data_key] = listbox
            elif widget_type == 'list_editor':
                # 簡單的列表編輯器（用於evoland和material）
                list_data = data_value if isinstance(data_value, list) else []

                container = ttk.Frame(row_frame)
                container.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

                # 列表框（顯示卡片名稱和ID）
                listbox = tk.Listbox(container, height=5, exportselection=False)
                listbox.pack(side=tk.LEFT, fill='both', expand=True)

                # 儲存 card_id -> display_text 的映射
                card_display_map = {}

                # 載入卡片資料並建立映射
                if self.data_cache.get('cards') and 'cards' in self.data_cache['cards']:
                    for card in self.data_cache['cards']['cards']:
                        card_id = card.get('card_id', '')
                        card_name = card.get('card_name', card_id)
                        card_display_map[card_id] = f"{card_name} ({card_id})"

                # 顯示現有項目（顯示名稱而不只是ID）
                for item in list_data:
                    display_text = card_display_map.get(item, item)
                    listbox.insert(tk.END, display_text)

                # 按鈕區
                btn_frame = ttk.Frame(container)
                btn_frame.pack(side=tk.LEFT, fill='y', padx=(5,0))

                def add_item():
                    # 創建選擇對話框
                    dialog = tk.Toplevel(self.root)
                    dialog.title(f"選擇{label}")
                    dialog.geometry("400x500")
                    dialog.transient(self.root)
                    dialog.grab_set()

                    # 搜尋框
                    search_frame = ttk.Frame(dialog)
                    search_frame.pack(fill='x', padx=10, pady=5)
                    ttk.Label(search_frame, text="搜尋:").pack(side=tk.LEFT)
                    search_var = tk.StringVar()
                    search_entry = ttk.Entry(search_frame, textvariable=search_var)
                    search_entry.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

                    # 卡片列表
                    list_frame = ttk.Frame(dialog)
                    list_frame.pack(fill='both', expand=True, padx=10, pady=5)

                    scrollbar = ttk.Scrollbar(list_frame)
                    scrollbar.pack(side=tk.RIGHT, fill='y')

                    card_listbox = tk.Listbox(list_frame, yscrollcommand=scrollbar.set)
                    card_listbox.pack(side=tk.LEFT, fill='both', expand=True)
                    scrollbar.config(command=card_listbox.yview)

                    # 儲存卡片ID列表
                    card_ids = []

                    def update_card_list(filter_text=""):
                        card_listbox.delete(0, tk.END)
                        card_ids.clear()

                        if self.data_cache.get('cards') and 'cards' in self.data_cache['cards']:
                            for card in self.data_cache['cards']['cards']:
                                card_id = card.get('card_id', '')
                                card_name = card.get('card_name', card_id)
                                display = f"{card_name} ({card_id})"

                                # 過濾
                                if not filter_text or filter_text.lower() in display.lower():
                                    card_listbox.insert(tk.END, display)
                                    card_ids.append(card_id)

                    # 搜尋功能
                    def on_search(*args):
                        update_card_list(search_var.get())

                    search_var.trace('w', on_search)
                    update_card_list()

                    # 按鈕
                    btn_frame_dialog = ttk.Frame(dialog)
                    btn_frame_dialog.pack(fill='x', padx=10, pady=5)

                    selected_card = [None]

                    def on_select():
                        sel = card_listbox.curselection()
                        if sel:
                            selected_card[0] = card_ids[sel[0]]
                            dialog.destroy()

                    def on_cancel():
                        dialog.destroy()

                    ttk.Button(btn_frame_dialog, text="確定", command=on_select).pack(side=tk.LEFT, padx=5)
                    ttk.Button(btn_frame_dialog, text="取消", command=on_cancel).pack(side=tk.LEFT)

                    # 雙擊也可以選擇
                    card_listbox.bind('<Double-Button-1>', lambda e: on_select())

                    dialog.wait_window()

                    if selected_card[0]:
                        card_id = selected_card[0]
                        display_text = card_display_map.get(card_id, card_id)
                        listbox.insert(tk.END, display_text)

                def remove_item():
                    sel = listbox.curselection()
                    if sel:
                        listbox.delete(sel[0])

                ttk.Button(btn_frame, text="➕ 添加", command=add_item, width=8).pack(pady=2)
                ttk.Button(btn_frame, text="➖ 移除", command=remove_item, width=8).pack(pady=2)

                self.widget_vars[data_key] = listbox
                # 儲存映射以便後續提取ID
                self.widget_vars[f"{data_key}_map"] = card_display_map

        create_form_row(form_frame, "Card ID", 'entry', 'card_id') # ID 應可編輯
        create_form_row(form_frame, "名稱", 'entry', 'card_name')
        create_form_row(form_frame, "圖片路徑", 'entry', 'card_image_path')
        create_form_row(form_frame, "稀有度", 'rarity_combobox', 'rarity')
        create_form_row(form_frame, "種族", 'race_combobox', 'card_race')
        create_form_row(form_frame, "元素", 'element_combobox', 'element')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        create_form_row(form_frame, "基礎 HP", 'spinbox', 'base_hp')
        create_form_row(form_frame, "基礎 ATK", 'spinbox', 'base_atk')
        create_form_row(form_frame, "基礎 REC", 'spinbox', 'base_recovery')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        # ✅ 等級系統欄位
        ttk.Label(form_frame, text="【等級系統】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_form_row(form_frame, "最高等級", 'spinbox', 'max_level')
        create_form_row(form_frame, "滿級經驗值", 'spinbox', 'max_exp')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        # ✅ 升星系統欄位
        ttk.Label(form_frame, text="【升星系統】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_form_row(form_frame, "星等", 'spinbox', 'rank')
        create_form_row(form_frame, "可進化卡片 (evoland)", 'list_editor', 'evoland')
        create_form_row(form_frame, "進化素材 (material)", 'list_editor', 'material')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        create_form_row(form_frame, "最大 SP", 'spinbox', 'max_sp')
        create_form_row(form_frame, "初始 SP", 'spinbox', 'initial_sp')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        create_form_row(form_frame, "主動技能", 'dynamic_combobox', 'active_skill_id', options={'data_key': 'active_skills', 'list_key': 'active_skills', 'id_key': 'skill_id'})
        create_form_row(
            form_frame,
            "隊長技能",
            'dynamic_listbox',
            'leader_skill_ids',
            options={
                'data_key': 'leader_skills',
                'list_key': 'leader_skills',
                'id_key': 'skill_id',
                'name_key': 'skill_name',
                'effect_types': self.ALL_PLAYER_EFFECT_TYPES
            }
        )
        # (您可以按需添加 'passive_skill_ids' 欄位)
        ttk.Button(form_frame, text="儲存變更", command=self.save_current_player_card, style='Accent.TButton').pack(pady=20)

    def add_skill_to_listbox(self, listbox, options):
        skill_data = self.data_cache.get(options['data_key'])
        skill_list = skill_data.get(options['list_key'], [])
        id_key = options['id_key']; name_key = options.get('name_key', id_key)
        skill_options = {
            self.format_skill_display_text(s.get(name_key), s.get(id_key)): s.get(id_key)
            for s in skill_list
        }
        
        dlg = tk.Toplevel(self.root); dlg.title("選擇要新增的技能"); dlg.geometry("300x400"); dlg.grab_set()
        ttk.Label(dlg, text=f"請選擇一個 {options['data_key']}").pack(pady=5)
        dlg_listbox = tk.Listbox(dlg, width=45, height=15); dlg_listbox.pack(padx=10, pady=5)
        
        for display_text in sorted(skill_options.keys()):
            dlg_listbox.insert(tk.END, display_text)
            
        def on_add():
            if not dlg_listbox.curselection(): return
            selected_display_text = dlg_listbox.get(dlg_listbox.curselection()[0])
            selected_skill_id = skill_options[selected_display_text]
            if selected_skill_id not in listbox.get(0, tk.END):
                listbox.insert(tk.END, selected_skill_id)
            dlg.destroy()
        ttk.Button(dlg, text="新增選定技能", command=on_add).pack(pady=10)
        
    def remove_skill_from_listbox(self, listbox):
        if not listbox.curselection(): return
        listbox.delete(listbox.curselection()[0])

    # --- 技能彈窗輔助 ---
    def open_skill_editor_dialog(self, *, data_key, list_key, id_key, name_key,
                                 effect_types, skill_ref=None,
                                 on_created=None, on_updated=None):
        """開啟可快速建立/編輯技能的彈窗"""
        default_skill = self.get_default_skill_template(data_key, id_key, name_key)
        initial_data = copy.deepcopy(skill_ref) if skill_ref else default_skill

        def handle_save(updated_data, original_id):
            updated_data[id_key] = self.ensure_skill_id_prefix(data_key, updated_data.get(id_key, ""))
            new_id = updated_data.get(id_key)
            if self.is_duplicate_skill_id(data_key, list_key, id_key, new_id, original_id):
                messagebox.showerror("錯誤", f"Skill ID {new_id} 已存在。", parent=self.root)
                return False

            if skill_ref is None:
                self.data_cache[data_key][list_key].append(updated_data)
                if on_created:
                    on_created(updated_data)
            else:
                skill_ref.clear()
                skill_ref.update(updated_data)
                if on_updated:
                    on_updated(updated_data)

            self.save_data_to_file(data_key)
            self.refresh_skill_management_list(data_key)
            return True

        SkillEditorWindow(
            self.root,
            data_key=data_key,
            id_key=id_key,
            name_key=name_key,
            skill_data=initial_data,
            effect_types=effect_types,
            schema=self.SKILL_EFFECT_SCHEMA,
            element_options=self.ELEMENT_OPTIONS,
            effect_descriptions=self.EFFECT_TYPE_DESCRIPTIONS,
            element_cn_to_en=self.ELEMENT_CN_TO_EN,  # ✅ 傳入元素映射
            element_en_to_cn=self.ELEMENT_EN_TO_CN,  # ✅ 傳入元素映射
            on_save=handle_save,
            id_prefix=self.get_skill_id_prefix(data_key)
        )

    def get_default_skill_template(self, data_key, id_key, name_key):
        template = {
            id_key: "",
            name_key: "新技能",
            "description": "",
            "effects": []
        }
        if data_key == 'active_skills':
            template.update({"skill_cost": 10, "duration": 1, "target_type": "SELF"})
        return template

    def is_duplicate_skill_id(self, data_key, list_key, id_key, new_id, original_id):
        if not new_id:
            return False
        for skill in self.data_cache.get(data_key, {}).get(list_key, []):
            if skill.get(id_key) == new_id and new_id != original_id:
                return True
        return False

    def find_skill_record(self, data_key, list_key, id_key, skill_id):
        for skill in self.data_cache.get(data_key, {}).get(list_key, []):
            if skill.get(id_key) == skill_id:
                return skill
        return None

    def refresh_skill_management_list(self, data_key):
        meta = self.skill_tab_meta.get(data_key)
        listbox = getattr(self, f"{data_key}_listbox", None)
        if not meta or not listbox:
            return
        listbox.delete(0, tk.END)
        for skill in self.data_cache.get(data_key, {}).get(meta['list_key'], []):
            listbox.insert(
                tk.END,
                self.format_skill_display_text(
                    skill.get(meta['name_key'], 'N/A'),
                    skill.get(meta['id_key'], '???')
                )
            )

    @staticmethod
    def format_skill_display_text(skill_name, skill_id):
        """UI 顯示：技能功能在上，技能 ID 在下"""
        return f"{skill_name or 'N/A'}\n{skill_id or '???'}"

    def format_effect_display_text(self, effect_type):
        effect_id = effect_type or 'UNKNOWN'
        description = self.EFFECT_TYPE_DESCRIPTIONS.get(effect_id, effect_id)
        return f"{description}\n{effect_id}"

    def on_tab_changed(self, event):
        """當分頁切換時，自動儲存當前正在編輯的玩家卡片"""
        # 只在離開玩家卡片分頁時才儲存
        if hasattr(self, 'current_selected_card_id') and self.current_selected_card_id and hasattr(self, 'widget_vars') and self.widget_vars:
            try:
                self.auto_save_current_player_card()
            except Exception as e:
                print(f"⚠️ 分頁切換時自動儲存失敗: {e}")

    def auto_save_current_player_card(self):
        """自動儲存當前卡片（靜默模式，不顯示訊息）"""
        if not self.current_selected_card_id:
            return

        card_to_update = None
        for i, card in enumerate(self.data_cache['cards']['cards']):
            if card.get('card_id') == self.current_selected_card_id:
                card_to_update = card
                break

        if not card_to_update:
            return

        try:
            for key, var in self.widget_vars.items():
                # 跳過映射鍵（不是實際數據欄位）
                if key.endswith('_map'):
                    continue

                if isinstance(var, tk.Listbox):
                    value = list(var.get(0, tk.END))

                    # 對於 evoland 和 material，從顯示文本中提取 card_id
                    if key in ['evoland', 'material']:
                        extracted_ids = []
                        for item in value:
                            # 從 "卡片名 (ID)" 格式中提取 ID
                            import re
                            match = re.search(r'\(([^)]+)\)$', item)
                            if match:
                                extracted_ids.append(match.group(1))
                            else:
                                # 如果沒有括號，直接使用原值（向後兼容）
                                extracted_ids.append(item)
                        value = extracted_ids
                else:
                    value = var.get()
                card_to_update[key] = value

            # (重要) 如果 ID 被修改了，更新追蹤的 ID
            new_id = card_to_update['card_id']
            self.current_selected_card_id = new_id

        except Exception as e:
            print(f"⚠️ 自動儲存卡片時發生錯誤: {e}")
            return

        # ✅ 靜默儲存到文件
        self.save_data_to_file('cards')
        print(f"✅ 已自動儲存卡片: {self.current_selected_card_id}")

    def save_current_player_card(self):
        if not self.current_selected_card_id:
            self.status_var.set("錯誤：沒有選擇卡片"); return

        card_to_update = None
        card_index = -1
        for i, card in enumerate(self.data_cache['cards']['cards']):
            if card.get('card_id') == self.current_selected_card_id:
                card_to_update = card
                card_index = i
                break

        if not card_to_update:
            self.status_var.set(f"錯誤：在快取中找不到 ID {self.current_selected_card_id}"); return

        try:
            for key, var in self.widget_vars.items():
                # 跳過映射鍵（不是實際數據欄位）
                if key.endswith('_map'):
                    continue

                if isinstance(var, tk.Listbox):
                    value = list(var.get(0, tk.END))

                    # 對於 evoland 和 material，從顯示文本中提取 card_id
                    if key in ['evoland', 'material']:
                        extracted_ids = []
                        for item in value:
                            # 從 "卡片名 (ID)" 格式中提取 ID
                            import re
                            match = re.search(r'\(([^)]+)\)$', item)
                            if match:
                                extracted_ids.append(match.group(1))
                            else:
                                # 如果沒有括號，直接使用原值（向後兼容）
                                extracted_ids.append(item)
                        value = extracted_ids
                else:
                    value = var.get()
                card_to_update[key] = value

            # (重要) 如果 ID 被修改了，更新追蹤的 ID
            new_id = card_to_update['card_id']
            self.current_selected_card_id = new_id

        except Exception as e:
            messagebox.showerror("讀取錯誤", f"從表單讀取資料時發生錯誤: {e}"); self.status_var.set("儲存失敗：讀取表單時出錯"); return

        self.save_data_to_file('cards')
        
        # 更新左側列表的顯示名稱
        new_name = card_to_update['card_name']
        self.player_card_listbox.delete(card_index)
        self.player_card_listbox.insert(card_index, f"{new_id} - {new_name}")
        self.player_card_listbox.select_set(card_index)

    def add_new_player_card(self):
        new_id = simpledialog.askstring("新增卡片", "請輸入新卡片的唯一 ID:", parent=self.root)
        if not new_id: return
        
        # 檢查 ID 是否已存在
        for card in self.data_cache['cards']['cards']:
            if card['card_id'] == new_id:
                messagebox.showerror("錯誤", "此 ID 已存在", parent=self.root)
                return
        
        # 建立一個新的空白卡片
        new_card = {
            "card_id": new_id,
            "card_name": "新卡片",
            "rarity": "COMMON",
            "card_race": "HUMAN",
            "element": "FIRE",
            "card_image_path": "",
            "base_hp": 10,
            "base_atk": 5,
            "base_recovery": 5,
            "max_level": 99,
            "max_exp": 900,
            "rank": 1,
            "evoland": [],
            "material": [],
            "max_sp": 3,
            "initial_sp": 1,
            "active_skill_id": "",
            "leader_skill_ids": []
        }
        
        self.data_cache['cards']['cards'].append(new_card)
        
        # 更新 UI
        self.player_card_listbox.insert(tk.END, f"{new_id} - 新卡片")
        self.player_card_listbox.selection_clear(0, tk.END)
        self.player_card_listbox.select_set(tk.END) # 選中新卡片
        self.player_card_listbox.event_generate("<<ListboxSelect>>") # 手動觸發選中事件
        
        # 立即儲存
        self.save_data_to_file('cards')

    def delete_current_player_card(self):
        if not self.player_card_listbox.curselection():
            messagebox.showerror("錯誤", "請先從列表選擇一張卡片", parent=self.root)
            return
            
        selected_index = self.player_card_listbox.curselection()[0]
        card_id = self.data_cache['cards']['cards'][selected_index]['card_id']
        
        if not messagebox.askyesno("確認刪除", f"確定要刪除卡片 {card_id} 嗎？\n此操作無法復原。", parent=self.root):
            return
            
        # 從快取中刪除
        self.data_cache['cards']['cards'].pop(selected_index)
        
        # 從 UI 中刪除
        self.player_card_listbox.delete(selected_index)
        
        # 清空右側面板
        self.clear_tab(self.player_card_detail_frame)
        ttk.Label(self.player_card_detail_frame, text="請從左側列表選擇一張卡片進行編輯").pack(padx=20, pady=20)
        self.current_selected_card_id = None
        
        # 立即儲存
        self.save_data_to_file('cards')

    # --- 5. "敵方卡片" 分頁 (全新功能) ---
    def populate_enemy_cards_tab(self):
        """建立 "敵方卡片" 分頁的 UI (與我方卡片幾乎相同)"""
        self.clear_tab(self.tab_enemy_cards)
        
        enemies_data = self.data_cache.get('enemies')
        if not enemies_data or 'enemies' not in enemies_data:
            ttk.Label(self.tab_enemy_cards, text="enemies.json 格式錯誤或為空").pack()
            return

        # --- 雙欄佈局 ---
        left_frame = ttk.Frame(self.tab_enemy_cards, width=250)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        # 新增/刪除 按鈕
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x')
        ttk.Button(btn_frame, text="新增敵人", command=self.add_new_enemy).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(btn_frame, text="刪除選定", command=self.delete_current_enemy).pack(side=tk.LEFT, expand=True, fill='x')

        self.enemy_card_listbox = tk.Listbox(left_frame, exportselection=False)
        self.enemy_card_listbox.pack(fill=tk.BOTH, expand=True)

        for i, enemy in enumerate(enemies_data['enemies']):
            self.enemy_card_listbox.insert(tk.END, f"{enemy.get('enemy_id', '???')} - {enemy.get('enemy_name', 'N/A')}")
        
        self.enemy_card_listbox.bind('<<ListboxSelect>>', self.on_enemy_card_selected)
        
        self.enemy_card_detail_frame = ttk.Frame(self.tab_enemy_cards)
        self.enemy_card_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.enemy_card_detail_frame, text="請從左側列表選擇一個敵人進行編輯").pack(padx=20, pady=20)

    def on_enemy_card_selected(self, event):
        """當使用者在 Listbox 點擊敵人時觸發"""
        if not self.enemy_card_listbox.curselection():
            return
            
        selected_index = self.enemy_card_listbox.curselection()[0]
        selected_enemy_data = self.data_cache['enemies']['enemies'][selected_index]
        self.current_selected_enemy_id = selected_enemy_data.get('enemy_id')

        self.clear_tab(self.enemy_card_detail_frame)
        self.widget_vars = {} # (共用 self.widget_vars)

        canvas = tk.Canvas(self.enemy_card_detail_frame)
        scrollbar = ttk.Scrollbar(self.enemy_card_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # ✅ 綁定鼠標滾輪
        self.bind_mousewheel(canvas)

        # (與我方卡片相同的輔助函數)
        def create_form_row(parent, label, widget_type, data_key, options=None):
            row_frame = ttk.Frame(parent); row_frame.pack(fill='x', pady=2)
            ttk.Label(row_frame, text=label, width=15).pack(side=tk.LEFT)
            data_value = selected_enemy_data.get(data_key)
            if widget_type == 'entry':
                var = tk.StringVar(value=data_value); widget = ttk.Entry(row_frame, textvariable=var); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(data_value or 0)); widget = ttk.Spinbox(row_frame, from_=-1, to=99999, textvariable=var); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'combobox':
                var = tk.StringVar(value=data_value); widget = ttk.Combobox(row_frame, textvariable=var, values=options, state='readonly'); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); self.widget_vars[data_key] = var
            elif widget_type == 'dynamic_listbox':
                list_frame = ttk.Frame(row_frame); list_frame.pack(side=tk.LEFT, fill='x', expand=True, padx=5); listbox = tk.Listbox(list_frame, height=4, exportselection=False);
                if data_value:
                    for item in data_value: listbox.insert(tk.END, item)
                listbox.pack(side=tk.LEFT, fill='x', expand=True);
                btn_frame = ttk.Frame(list_frame); btn_frame.pack(side=tk.LEFT, padx=5)

                add_cmd = partial(self.add_skill_to_listbox, listbox, options)
                remove_cmd = partial(self.remove_skill_from_listbox, listbox)
                ttk.Button(btn_frame, text="加入既有", command=add_cmd).pack(pady=2, fill='x')
                ttk.Button(btn_frame, text="移除", command=remove_cmd).pack(pady=2, fill='x')

                effect_types = options.get('effect_types')
                if effect_types is None:
                    effect_types = self.ALL_ENEMY_EFFECT_TYPES if options.get('data_key') == 'enemy_skills' else self.ALL_PLAYER_EFFECT_TYPES

                allow_inline = options.get('allow_inline_edit', True)

                def on_new_skill_created(saved_skill):
                    new_id = saved_skill.get(options['id_key'])
                    if new_id and new_id not in listbox.get(0, tk.END):
                        listbox.insert(tk.END, new_id)
                        listbox.selection_clear(0, tk.END)
                        listbox.select_set(tk.END)

                def create_new_skill_inline():
                    self.open_skill_editor_dialog(
                        data_key=options['data_key'],
                        list_key=options['list_key'],
                        id_key=options['id_key'],
                        name_key=options.get('name_key', options['id_key']),
                        effect_types=effect_types,
                        on_created=on_new_skill_created
                    )

                def edit_selected_skill_inline():
                    if not listbox.curselection():
                        messagebox.showerror("錯誤", "請先選擇列表中的技能", parent=self.root)
                        return
                    selected_skill_id = listbox.get(listbox.curselection()[0])
                    skill_ref = self.find_skill_record(options['data_key'], options['list_key'], options['id_key'], selected_skill_id)
                    if not skill_ref:
                        messagebox.showerror("錯誤", f"在 {options['data_key']} 中找不到 {selected_skill_id}", parent=self.root)
                        return
                    self.open_skill_editor_dialog(
                        data_key=options['data_key'],
                        list_key=options['list_key'],
                        id_key=options['id_key'],
                        name_key=options.get('name_key', options['id_key']),
                        effect_types=effect_types,
                        skill_ref=skill_ref
                    )

                if allow_inline:
                    ttk.Button(btn_frame, text="創建技能", command=create_new_skill_inline).pack(pady=2, fill='x')
                    ttk.Button(btn_frame, text="編輯技能", command=edit_selected_skill_inline).pack(pady=2, fill='x')

                self.widget_vars[data_key] = listbox

        # --- 根據 enemies.json 和設計文檔定義表單 ---
        create_form_row(form_frame, "Enemy ID", 'entry', 'enemy_id')
        create_form_row(form_frame, "名稱", 'entry', 'enemy_name')
        create_form_row(form_frame, "圖片路徑", 'entry', 'sprite_path')
        create_form_row(form_frame, "元素", 'element_combobox', 'element')
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        create_form_row(form_frame, "最大 HP", 'spinbox', 'max_hp')
        create_form_row(form_frame, "基礎 ATK", 'spinbox', 'base_atk')
        create_form_row(form_frame, "攻擊 CD", 'spinbox', 'attack_cd', options={'from_': -1}) # -1 CD 可能有特殊意義
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        
        # --- 模組化動態欄位 ---
        create_form_row(form_frame, "被動技能", 'dynamic_listbox', 'passive_skill_ids',
                        options={
                            'data_key': 'enemy_skills',
                            'list_key': 'enemy_skills',
                            'id_key': 'skill_id',
                            'name_key': 'skill_name',
                            'effect_types': self.ALL_ENEMY_EFFECT_TYPES
                        })
        create_form_row(form_frame, "攻擊技能", 'dynamic_listbox', 'attack_skill_ids',
                        options={
                            'data_key': 'enemy_skills',
                            'list_key': 'enemy_skills',
                            'id_key': 'skill_id',
                            'name_key': 'skill_name',
                            'effect_types': self.ALL_ENEMY_EFFECT_TYPES
                        })
        
        ttk.Button(form_frame, text="儲存變更", command=self.save_current_enemy_card, style='Accent.TButton').pack(pady=20)

    def save_current_enemy_card(self):
        """儲存當前編輯的敵人"""
        if not self.current_selected_enemy_id:
            self.status_var.set("錯誤：沒有選擇敵人"); return

        enemy_to_update = None
        enemy_index = -1
        for i, enemy in enumerate(self.data_cache['enemies']['enemies']):
            if enemy.get('enemy_id') == self.current_selected_enemy_id:
                enemy_to_update = enemy
                enemy_index = i
                break
        
        if not enemy_to_update:
            self.status_var.set(f"錯誤：在快取中找不到 ID {self.current_selected_enemy_id}"); return

        try:
            for key, var in self.widget_vars.items():
                if isinstance(var, tk.Listbox): value = list(var.get(0, tk.END))
                else: value = var.get()
                enemy_to_update[key] = value
            
            new_id = enemy_to_update['enemy_id']
            self.current_selected_enemy_id = new_id
                
        except Exception as e:
            messagebox.showerror("讀取錯誤", f"從表單讀取資料時發生錯誤: {e}"); self.status_var.set("儲存失敗：讀取表單時出錯"); return

        self.save_data_to_file('enemies')
        
        new_name = enemy_to_update['enemy_name']
        self.enemy_card_listbox.delete(enemy_index)
        self.enemy_card_listbox.insert(enemy_index, f"{new_id} - {new_name}")
        self.enemy_card_listbox.select_set(enemy_index)

    def add_new_enemy(self):
        new_id = simpledialog.askstring("新增敵人", "請輸入新敵人的唯一 ID:", parent=self.root)
        if not new_id: return
        
        for enemy in self.data_cache['enemies']['enemies']:
            if enemy['enemy_id'] == new_id:
                messagebox.showerror("錯誤", "此 ID 已存在", parent=self.root)
                return
        
        new_enemy = {
            "enemy_id": new_id,
            "enemy_name": "新敵人",
            "sprite_path": "res://assets/enemies/placeholder.png",
            "element": "FIRE",
            "max_hp": 100,
            "base_atk": 10,
            "attack_cd": 1,
            "passive_skill_ids": [],
            "attack_skill_ids": []
        }
        
        self.data_cache['enemies']['enemies'].append(new_enemy)
        self.enemy_card_listbox.insert(tk.END, f"{new_id} - 新敵人")
        self.enemy_card_listbox.selection_clear(0, tk.END)
        self.enemy_card_listbox.select_set(tk.END)
        self.enemy_card_listbox.event_generate("<<ListboxSelect>>")
        self.save_data_to_file('enemies')

    def delete_current_enemy(self):
        if not self.enemy_card_listbox.curselection():
            messagebox.showerror("錯誤", "請先從列表選擇一個敵人", parent=self.root); return
            
        selected_index = self.enemy_card_listbox.curselection()[0]
        enemy_id = self.data_cache['enemies']['enemies'][selected_index]['enemy_id']
        
        if not messagebox.askyesno("確認刪除", f"確定要刪除敵人 {enemy_id} 嗎？\n此操作無法復原。", parent=self.root):
            return
            
        self.data_cache['enemies']['enemies'].pop(selected_index)
        self.enemy_card_listbox.delete(selected_index)
        self.clear_tab(self.enemy_card_detail_frame)
        ttk.Label(self.enemy_card_detail_frame, text="請從左側列表選擇一個敵人進行編輯").pack(padx=20, pady=20)
        self.current_selected_enemy_id = None
        self.save_data_to_file('enemies')

    # --- 6. "技能" 分頁 (全新功能，包含效果編輯器) ---
    
    def populate_player_skills_tab(self):
        """建立 "我方技能" 分頁的 UI (使用子分頁)"""
        self.clear_tab(self.tab_player_skills)
        
        # 建立子分頁
        sub_notebook = ttk.Notebook(self.tab_player_skills)
        
        self.tab_active_skills = ttk.Frame(sub_notebook)
        self.tab_leader_skills = ttk.Frame(sub_notebook)
        
        sub_notebook.add(self.tab_active_skills, text='主動技能 (Active Skills)')
        sub_notebook.add(self.tab_leader_skills, text='隊長技能 (Leader Skills)')
        
        sub_notebook.pack(expand=True, fill='both', padx=5, pady=5)
        
        # 填充兩個子分頁
        self.populate_skill_sub_tab(
            self.tab_active_skills,
            data_key='active_skills',
            list_key='active_skills',
            id_key='skill_id',
            name_key='skill_name',
            effect_types=self.ALL_PLAYER_EFFECT_TYPES
        )
        self.populate_skill_sub_tab(
            self.tab_leader_skills,
            data_key='leader_skills',
            list_key='leader_skills',
            id_key='skill_id',
            name_key='skill_name',
            effect_types=self.ALL_PLAYER_EFFECT_TYPES
        )

    def populate_enemy_skills_tab(self):
        """建立 "敵方技能" 分頁的 UI"""
        self.clear_tab(self.tab_enemy_skills)
        self.populate_skill_sub_tab(
            self.tab_enemy_skills,
            data_key='enemy_skills',
            list_key='enemy_skills',
            id_key='skill_id',
            name_key='skill_name',
            effect_types=self.ALL_ENEMY_EFFECT_TYPES
        )

    def populate_skill_sub_tab(self, parent_tab, data_key, list_key, id_key, name_key, effect_types):
        """
        通用的技能編輯器 UI 生成函數 (雙欄佈局)
        """
        skill_data_root = self.data_cache.get(data_key)
        if not skill_data_root or list_key not in skill_data_root:
            ttk.Label(parent_tab, text=f"{data_key}.json 格式錯誤或為空").pack()
            return
            
        # --- 雙欄佈局 ---
        left_frame = ttk.Frame(parent_tab, width=250)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        # 新增/刪除 按鈕
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x')
        add_cmd = partial(self.add_new_skill, data_key, list_key, id_key, name_key)
        del_cmd = partial(self.delete_current_skill, data_key, list_key, id_key)
        ttk.Button(btn_frame, text="新增技能", command=add_cmd).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(btn_frame, text="刪除選定", command=del_cmd).pack(side=tk.LEFT, expand=True, fill='x')

        listbox = tk.Listbox(left_frame, exportselection=False)
        listbox.pack(fill=tk.BOTH, expand=True)

        for i, skill in enumerate(skill_data_root[list_key]):
            listbox.insert(
                tk.END,
                self.format_skill_display_text(
                    skill.get(name_key, 'N/A'),
                    skill.get(id_key, '???')
                )
            )
        
        detail_frame = ttk.Frame(parent_tab)
        detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(detail_frame, text="請從左側列表選擇一個技能進行編輯").pack(padx=20, pady=20)
        
        # 綁定事件 (使用 lambda 傳遞額外參數)
        on_select_cmd = lambda event, dk=data_key, lk=list_key, ik=id_key, nk=name_key, ef=effect_types, df=detail_frame, lb=listbox: \
            self.on_skill_selected(event, dk, lk, ik, nk, ef, df, lb)
            
        listbox.bind('<<ListboxSelect>>', on_select_cmd)
        
        # 將 listbox 儲存起來，以便刪除時更新
        setattr(self, f"{data_key}_listbox", listbox)
        self.skill_tab_meta[data_key] = {
            'list_key': list_key,
            'id_key': id_key,
            'name_key': name_key
        }

    def on_skill_selected(self, event, data_key, list_key, id_key, name_key, effect_types, detail_frame, listbox):
        """當使用者在 Listbox 點擊技能時觸發"""
        if not listbox.curselection():
            return
            
        selected_index = listbox.curselection()[0]
        selected_skill_data = self.data_cache[data_key][list_key][selected_index]
        
        # 清空並重建右側表單
        self.clear_tab(detail_frame)
        
        # 使用一個專屬的 widget_vars 字典
        current_vars = {}
        setattr(self, f"{data_key}_widget_vars", current_vars) # 儲存到 self.active_skills_widget_vars

        canvas = tk.Canvas(detail_frame)
        scrollbar = ttk.Scrollbar(detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # ✅ 綁定鼠標滾輪
        self.bind_mousewheel(canvas)

        # --- 輔助函數 (與卡片類似，但使用 current_vars) ---
        def create_form_row(parent, label, widget_type, data_key_in_skill):
            row_frame = ttk.Frame(parent); row_frame.pack(fill='x', pady=2)
            ttk.Label(row_frame, text=label, width=15).pack(side=tk.LEFT)
            data_value = selected_skill_data.get(data_key_in_skill)
            
            if widget_type == 'entry':
                var = tk.StringVar(value=data_value)
                if data_key_in_skill == id_key:
                    self.attach_skill_prefix_trace(var, data_key)
                widget = ttk.Entry(row_frame, textvariable=var)
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                current_vars[data_key_in_skill] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(data_value or 0)); widget = ttk.Spinbox(row_frame, from_=0, to=9999, textvariable=var); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); current_vars[data_key_in_skill] = var
            elif widget_type == 'text': # 多行文字
                widget = tk.Text(row_frame, height=3, width=40); widget.insert(tk.END, data_value or ""); widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5); current_vars[data_key_in_skill] = widget
            
        # --- 建立表單 (通用) ---
        create_form_row(form_frame, "Skill ID", 'entry', id_key)
        create_form_row(form_frame, "名稱", 'entry', name_key)
        if 'description' in selected_skill_data:
            create_form_row(form_frame, "描述", 'text', 'description')
        
        # --- 建立表單 (Active Skill 專用) ---
        if data_key == 'active_skills':
            if 'skill_cost' in selected_skill_data:
                create_form_row(form_frame, "CD (skill_cost)", 'spinbox', 'skill_cost')
            if 'duration' in selected_skill_data:
                create_form_row(form_frame, "持續 (duration)", 'spinbox', 'duration')
            if 'target_type' in selected_skill_data:
                # 目標類型（顯示中文，存儲英文）
                current_en = selected_skill_data.get('target_type', 'SELF')
                current_cn = self.TARGET_EN_TO_CN.get(current_en, '自己')

                display_var = tk.StringVar(value=current_cn)
                en_var = tk.StringVar(value=current_en)

                row_frame = ttk.Frame(form_frame); row_frame.pack(fill='x', pady=2)
                ttk.Label(row_frame, text="目標 (target_type)", width=15).pack(side=tk.LEFT)
                widget = ttk.Combobox(row_frame, textvariable=display_var, values=list(self.TARGET_CN_TO_EN.keys()), state='readonly')
                widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

                def on_change(event):
                    selected_cn = display_var.get()
                    actual_en = self.TARGET_CN_TO_EN.get(selected_cn, 'SELF')
                    en_var.set(actual_en)

                widget.bind('<<ComboboxSelected>>', on_change)
                current_vars['target_type'] = en_var
        
        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)
        
        # --- (核心) 效果編輯器 UI ---
        ttk.Label(form_frame, text="技能效果 (Effects)", font=("Arial", 12)).pack(anchor='w')
        effect_frame = ttk.Frame(form_frame)
        effect_frame.pack(fill='x', expand=True, pady=5)
        
        effect_listbox = tk.Listbox(effect_frame, height=6, exportselection=False)
        effect_listbox.pack(side=tk.LEFT, fill='x', expand=True, padx=(0, 5))
        
        # 填充效果列表
        effects_list = selected_skill_data.get('effects', [])
        for i, effect in enumerate(effects_list):
            effect_listbox.insert(
                tk.END,
                self.format_effect_display_text(effect.get('effect_type'))
            )
        
        # 將 listbox 存入 vars，以便儲存時讀取
        current_vars['effects_listbox'] = effect_listbox
        
        # 按鈕
        effect_btn_frame = ttk.Frame(effect_frame)
        effect_btn_frame.pack(side=tk.LEFT)
        
        # --- 回調 (Callback) 函數 ---
        def on_effect_saved(new_effect_data):
            """當彈窗儲存時，更新 UI 列表和快取"""
            # 檢查是新增還是編輯
            try:
                # 編輯
                edit_index = effect_listbox.curselection()[0]
                effects_list[edit_index] = new_effect_data # 更新快取
                effect_listbox.delete(edit_index) # 更新 UI
                effect_listbox.insert(
                    edit_index,
                    self.format_effect_display_text(new_effect_data['effect_type'])
                )
                effect_listbox.select_set(edit_index)
            except IndexError:
                # 新增
                effects_list.append(new_effect_data) # 更新快取
                new_index = tk.END
                effect_listbox.insert(
                    new_index,
                    self.format_effect_display_text(new_effect_data['effect_type'])
                ) # 更新 UI
                
        def add_effect():
            EffectEditorWindow(
                self.root, 
                self.SKILL_EFFECT_SCHEMA, 
                effect_types, 
                self.ELEMENT_OPTIONS,
				self.EFFECT_TYPE_DESCRIPTIONS, # <-- 在此處新增
                self.ELEMENT_CN_TO_EN,  # ✅ 傳入元素映射
                self.ELEMENT_EN_TO_CN,  # ✅ 傳入元素映射
                current_effect_data=None, # 傳入 None (新增)
                callback=on_effect_saved
            )
        
        def edit_effect():
            if not effect_listbox.curselection(): return
            edit_index = effect_listbox.curselection()[0]
            current_effect = effects_list[edit_index]
            
            EffectEditorWindow(
                self.root, 
                self.SKILL_EFFECT_SCHEMA, 
                effect_types, 
                self.ELEMENT_OPTIONS,
				self.EFFECT_TYPE_DESCRIPTIONS, # <-- 在此處新增
                self.ELEMENT_CN_TO_EN,  # ✅ 傳入元素映射
                self.ELEMENT_EN_TO_CN,  # ✅ 傳入元素映射
                current_effect_data=current_effect, # 傳入當前資料 (編輯)
                callback=on_effect_saved
            )
            
        def remove_effect():
            if not effect_listbox.curselection(): return
            remove_index = effect_listbox.curselection()[0]
            if not messagebox.askyesno("確認", "確定要刪除這個效果嗎?", parent=self.root):
                return
            effects_list.pop(remove_index) # 從快取移除
            effect_listbox.delete(remove_index) # 從 UI 移除
            # (需要重新整理索引)
            effect_listbox.delete(0, tk.END)
            for i, effect in enumerate(effects_list):
                effect_listbox.insert(
                    tk.END,
                    self.format_effect_display_text(effect.get('effect_type'))
                )
        
        ttk.Button(effect_btn_frame, text="新增效果", command=add_effect).pack(pady=2)
        ttk.Button(effect_btn_frame, text="編輯選定", command=edit_effect).pack(pady=2)
        ttk.Button(effect_btn_frame, text="移除選定", command=remove_effect).pack(pady=2)
        
        # --- 儲存按鈕 ---
        save_cmd = partial(self.save_current_skill, data_key, list_key, id_key, name_key, listbox)
        ttk.Button(form_frame, text="儲存此技能變更", command=save_cmd, style='Accent.TButton').pack(pady=20)

    def save_current_skill(self, data_key, list_key, id_key, name_key, listbox):
        """儲存當前編輯的技能"""
        if not listbox.curselection():
            self.status_var.set("錯誤：沒有選擇技能"); return
            
        selected_index = listbox.curselection()[0]
        skill_to_update = self.data_cache[data_key][list_key][selected_index]
        current_vars = getattr(self, f"{data_key}_widget_vars") # 取得對應的 vars 字典

        try:
            for key, var in current_vars.items():
                if key == 'effects_listbox':
                    # 效果列表已在彈窗回調時直接修改了 skill_to_update['effects']
                    # 所以這裡不需要讀取
                    continue
                elif isinstance(var, tk.Text):
                    value = var.get("1.0", tk.END).strip()
                else:
                    value = var.get()

                skill_to_update[key] = value

        except Exception as e:
            messagebox.showerror("讀取錯誤", f"從表單讀取資料時發生錯誤: {e}"); self.status_var.set("儲存失敗：讀取表單時出錯"); return

        skill_to_update[id_key] = self.ensure_skill_id_prefix(data_key, skill_to_update.get(id_key, ""))

        self.save_data_to_file(data_key)
        
        # 更新左側列表
        new_id = skill_to_update[id_key]
        new_name = skill_to_update[name_key]
        listbox.delete(selected_index)
        listbox.insert(
            selected_index,
            self.format_skill_display_text(new_name, new_id)
        )
        listbox.select_set(selected_index)
        self.status_var.set(f"技能 {new_id} 儲存成功！")
    
    def add_new_skill(self, data_key, list_key, id_key, name_key):
        new_id = simpledialog.askstring("新增技能", "請輸入新技能的唯一 ID:", parent=self.root)
        if not new_id: return
        new_id = self.ensure_skill_id_prefix(data_key, new_id)

        for skill in self.data_cache[data_key][list_key]:
            if skill[id_key] == new_id:
                messagebox.showerror("錯誤", "此 ID 已存在", parent=self.root); return
        
        new_skill = {
            id_key: new_id,
            name_key: "新技能",
            "description": "新技能描述",
            "effects": []
        }
        if data_key == 'active_skills':
            new_skill.update({"skill_cost": 10, "duration": 1, "target_type": "SELF"})

        self.data_cache[data_key][list_key].append(new_skill)
        
        listbox = getattr(self, f"{data_key}_listbox")
        listbox.insert(
            tk.END,
            self.format_skill_display_text("新技能", new_id)
        )
        listbox.selection_clear(0, tk.END)
        listbox.select_set(tk.END)
        listbox.event_generate("<<ListboxSelect>>")
        self.save_data_to_file(data_key)

    def delete_current_skill(self, data_key, list_key, id_key):
        listbox = getattr(self, f"{data_key}_listbox")
        if not listbox.curselection():
            messagebox.showerror("錯誤", "請先從列表選擇一個技能", parent=self.root); return

        selected_index = listbox.curselection()[0]
        skill_id = self.data_cache[data_key][list_key][selected_index][id_key]
        
        if not messagebox.askyesno("確認刪除", f"確定要刪除技能 {skill_id} 嗎？\n此操作無法復原。", parent=self.root):
            return
            
        self.data_cache[data_key][list_key].pop(selected_index)
        listbox.delete(selected_index)
        
        # 清空右側面板 (找到對應的 detail_frame)
        parent_tab = listbox.master.master # listbox -> left_frame -> parent_tab
        detail_frame = parent_tab.winfo_children()[1] # [0] is left_frame, [1] is detail_frame
        self.clear_tab(detail_frame)
        ttk.Label(detail_frame, text="請從左側列表選擇一個技能進行編輯").pack(padx=20, pady=20)
        
        self.save_data_to_file(data_key)

    # ==================== 區域管理標籤 ====================

    def populate_regions_tab(self):
        """建立「區域管理」標籤頁的 UI（三欄佈局：區域 → 章節 → 關卡）"""
        self.clear_tab(self.tab_regions)

        regions_data = self.data_cache.get('regions', {})
        regions_list = regions_data.get('regions', [])

        if not isinstance(regions_list, list):
            ttk.Label(self.tab_regions, text="regions.json 格式錯誤或為空").pack()
            return

        # 主容器
        main_frame = ttk.Frame(self.tab_regions)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # --- 第一欄：區域列表 ---
        region_frame = ttk.Frame(main_frame, width=250)
        region_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 5))
        region_frame.pack_propagate(False)

        ttk.Label(region_frame, text="區域列表", font=("Noto Sans TC", 11, 'bold')).pack()

        region_btn_frame = ttk.Frame(region_frame)
        region_btn_frame.pack(fill='x', pady=5)
        ttk.Button(region_btn_frame, text="新增", command=self.add_new_region).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(region_btn_frame, text="刪除", command=self.delete_region).pack(side=tk.LEFT, expand=True, fill='x')

        self.region_listbox = tk.Listbox(region_frame, exportselection=False)
        self.region_listbox.pack(fill=tk.BOTH, expand=True)

        for region in regions_list:
            region_id = region.get('region_id', '???')
            region_name = region.get('region_name', '未命名')
            self.region_listbox.insert(tk.END, f"{region_id} - {region_name}")

        self.region_listbox.bind('<<ListboxSelect>>', self.on_region_selected)

        # --- 第二欄：章節列表 ---
        chapter_frame = ttk.Frame(main_frame, width=350)
        chapter_frame.pack(side=tk.LEFT, fill=tk.Y, padx=5)
        chapter_frame.pack_propagate(False)

        ttk.Label(chapter_frame, text="章節列表", font=("Noto Sans TC", 11, 'bold')).pack()

        chapter_btn_frame = ttk.Frame(chapter_frame)
        chapter_btn_frame.pack(fill='x', pady=5)
        ttk.Button(chapter_btn_frame, text="新增", command=self.add_new_chapter).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(chapter_btn_frame, text="刪除", command=self.delete_chapter).pack(side=tk.LEFT, expand=True, fill='x')

        self.chapter_listbox = tk.Listbox(chapter_frame, exportselection=False)
        self.chapter_listbox.pack(fill=tk.BOTH, expand=True)
        self.chapter_listbox.bind('<<ListboxSelect>>', self.on_chapter_selected)

        # --- 第三欄：章節詳情編輯 ---
        self.chapter_detail_frame = ttk.Frame(main_frame)
        self.chapter_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(5, 0))

        ttk.Label(self.chapter_detail_frame, text="請從左側選擇區域和章節").pack(padx=20, pady=20)

    def on_region_selected(self, event):
        """當選擇區域時，載入該區域的章節列表"""
        if not self.region_listbox.curselection():
            return

        selected_index = self.region_listbox.curselection()[0]
        regions_list = self.data_cache['regions']['regions']
        self.current_region_index = selected_index
        self.current_region_data = regions_list[selected_index]

        # 更新章節列表
        self.chapter_listbox.delete(0, tk.END)
        chapters = self.current_region_data.get('chapters', [])

        for chapter in chapters:
            chapter_id = chapter.get('chapter_id', '???')
            chapter_name = chapter.get('chapter_name', '未命名')
            is_independent = chapter.get('is_independent', True)
            require_prev = chapter.get('require_previous', False)

            status = " [獨立]" if is_independent else (" [需前置]" if require_prev else "")
            self.chapter_listbox.insert(tk.END, f"{chapter_id} - {chapter_name}{status}")

        # 清空章節詳情
        self.clear_tab(self.chapter_detail_frame)
        ttk.Label(self.chapter_detail_frame, text="請選擇章節進行編輯").pack(padx=20, pady=20)

    def on_chapter_selected(self, event):
        """當選擇章節時，顯示章節詳情編輯表單"""
        if not self.chapter_listbox.curselection():
            return

        selected_index = self.chapter_listbox.curselection()[0]
        chapters = self.current_region_data.get('chapters', [])
        self.current_chapter_index = selected_index
        self.current_chapter_data = chapters[selected_index]

        # 清空並重建表單
        self.clear_tab(self.chapter_detail_frame)

        canvas = tk.Canvas(self.chapter_detail_frame)
        scrollbar = ttk.Scrollbar(self.chapter_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # ✅ 綁定鼠標滾輪
        self.bind_mousewheel(canvas)

        self.chapter_widget_vars = {}

        # 創建表單
        ttk.Label(form_frame, text="章節詳情", font=("Noto Sans TC", 12, 'bold')).pack(pady=10)

        # 章節ID
        self.create_chapter_form_row(form_frame, "章節ID", 'entry', 'chapter_id')

        # 章節名稱
        self.create_chapter_form_row(form_frame, "章節名稱", 'entry', 'chapter_name')

        # 章節描述
        self.create_chapter_form_row(form_frame, "章節描述", 'text', 'chapter_desc')

        # 是否獨立
        self.create_chapter_form_row(form_frame, "獨立章節", 'checkbox', 'is_independent')

        # 需要前置
        self.create_chapter_form_row(form_frame, "需要前置章節", 'checkbox', 'require_previous')

        # 前置章節ID
        self.create_chapter_form_row(form_frame, "前置章節ID", 'entry', 'previous_chapter')

        # 關卡列表（可選擇式新增）
        ttk.Label(form_frame, text="關卡列表", font=("Noto Sans TC", 10, 'bold')).pack(anchor='w', pady=(10, 5))

        stages_list_frame = ttk.Frame(form_frame)
        stages_list_frame.pack(fill=tk.BOTH, expand=True, pady=5)

        # 關卡列表框
        self.chapter_stages_listbox = tk.Listbox(stages_list_frame, height=8)
        self.chapter_stages_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        stages_scroll = ttk.Scrollbar(stages_list_frame, orient="vertical", command=self.chapter_stages_listbox.yview)
        self.chapter_stages_listbox.configure(yscrollcommand=stages_scroll.set)
        stages_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        # 填入現有關卡列表
        current_stages = self.current_chapter_data.get('stages', [])
        for stage_id in current_stages:
            # 嘗試從 stages.json 獲取關卡名稱
            stage_name = self.get_stage_name(stage_id)
            display_text = f"{stage_id} - {stage_name}" if stage_name else stage_id
            self.chapter_stages_listbox.insert(tk.END, display_text)

        # 操作按鈕
        stages_btn_frame = ttk.Frame(form_frame)
        stages_btn_frame.pack(fill='x', pady=5)
        ttk.Button(stages_btn_frame, text="➕ 從列表選擇", command=self.add_stage_from_list).pack(side=tk.LEFT, padx=2)
        ttk.Button(stages_btn_frame, text="✍️ 手動輸入", command=self.add_stage_manually).pack(side=tk.LEFT, padx=2)
        ttk.Button(stages_btn_frame, text="🗑️ 刪除", command=self.delete_chapter_stage).pack(side=tk.LEFT, padx=2)

        # 保存按鈕
        save_frame = ttk.Frame(form_frame)
        save_frame.pack(fill='x', pady=10)
        ttk.Button(save_frame, text="💾 保存章節", command=self.save_current_chapter, style='Accent.TButton').pack(expand=True, fill='x')

    def create_chapter_form_row(self, parent, label, widget_type, data_key):
        """創建章節表單的一行"""
        row_frame = ttk.Frame(parent)
        row_frame.pack(fill='x', pady=2)
        ttk.Label(row_frame, text=label, width=15).pack(side=tk.LEFT)

        data_value = self.current_chapter_data.get(data_key)

        if widget_type == 'entry':
            var = tk.StringVar(value=data_value or "")
            widget = ttk.Entry(row_frame, textvariable=var)
            widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.chapter_widget_vars[data_key] = var

        elif widget_type == 'text':
            text_widget = tk.Text(row_frame, height=3, width=40)
            text_widget.insert('1.0', data_value or "")
            text_widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.chapter_widget_vars[data_key] = text_widget

        elif widget_type == 'checkbox':
            var = tk.BooleanVar(value=data_value if isinstance(data_value, bool) else False)
            widget = ttk.Checkbutton(row_frame, variable=var)
            widget.pack(side=tk.LEFT, padx=5)
            self.chapter_widget_vars[data_key] = var

    def save_current_chapter(self):
        """保存當前章節的修改"""
        if not hasattr(self, 'current_chapter_data'):
            return

        # 更新章節數據
        self.current_chapter_data['chapter_id'] = self.chapter_widget_vars['chapter_id'].get()
        self.current_chapter_data['chapter_name'] = self.chapter_widget_vars['chapter_name'].get()
        self.current_chapter_data['chapter_desc'] = self.chapter_widget_vars['chapter_desc'].get('1.0', 'end-1c')
        self.current_chapter_data['is_independent'] = self.chapter_widget_vars['is_independent'].get()
        self.current_chapter_data['require_previous'] = self.chapter_widget_vars['require_previous'].get()
        self.current_chapter_data['previous_chapter'] = self.chapter_widget_vars['previous_chapter'].get()

        # 處理關卡列表（從列表框讀取）
        stages_list = []
        for i in range(self.chapter_stages_listbox.size()):
            item_text = self.chapter_stages_listbox.get(i)
            # 提取關卡ID（格式：STAGE_001 - 關卡名稱 或 STAGE_001）
            stage_id = item_text.split(' - ')[0].strip()
            stages_list.append(stage_id)
        self.current_chapter_data['stages'] = stages_list

        # 保存到文件
        self.save_data_to_file('regions')

        # 更新章節列表顯示
        self.on_region_selected(None)
        self.chapter_listbox.selection_set(self.current_chapter_index)

        messagebox.showinfo("成功", "章節已保存", parent=self.root)

    def add_new_region(self):
        """新增區域"""
        region_id = simpledialog.askstring("新增區域", "請輸入區域ID (例如: region6):", parent=self.root)
        if not region_id:
            return

        region_name = simpledialog.askstring("新增區域", "請輸入區域名稱:", parent=self.root)
        if not region_name:
            return

        region_icon = simpledialog.askstring("新增區域", "請輸入區域圖標 (emoji):", parent=self.root)

        new_region = {
            "region_id": region_id.strip(),
            "region_name": region_name.strip(),
            "region_icon": region_icon.strip() if region_icon else "📍",
            "chapters": []
        }

        self.data_cache['regions']['regions'].append(new_region)
        self.save_data_to_file('regions')
        self.populate_regions_tab()
        messagebox.showinfo("成功", f"區域 {region_id} 已新增", parent=self.root)

    def delete_region(self):
        """刪除選中的區域"""
        if not self.region_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的區域", parent=self.root)
            return

        selected_index = self.region_listbox.curselection()[0]
        region = self.data_cache['regions']['regions'][selected_index]
        region_id = region.get('region_id', '???')

        if not messagebox.askyesno("確認刪除", f"確定要刪除區域 {region_id} 嗎？\n此操作無法復原。", parent=self.root):
            return

        self.data_cache['regions']['regions'].pop(selected_index)
        self.save_data_to_file('regions')
        self.populate_regions_tab()

    def add_new_chapter(self):
        """新增章節到當前區域"""
        if not hasattr(self, 'current_region_data'):
            messagebox.showerror("錯誤", "請先選擇一個區域", parent=self.root)
            return

        chapter_id = simpledialog.askstring("新增章節", "請輸入章節ID (例如: R1_C4):", parent=self.root)
        if not chapter_id:
            return

        chapter_name = simpledialog.askstring("新增章節", "請輸入章節名稱:", parent=self.root)
        if not chapter_name:
            return

        new_chapter = {
            "chapter_id": chapter_id.strip(),
            "chapter_name": chapter_name.strip(),
            "chapter_desc": "",
            "require_previous": False,
            "previous_chapter": "",
            "is_independent": True,
            "stages": []
        }

        self.current_region_data['chapters'].append(new_chapter)
        self.save_data_to_file('regions')
        self.on_region_selected(None)
        messagebox.showinfo("成功", f"章節 {chapter_id} 已新增", parent=self.root)

    def delete_chapter(self):
        """刪除選中的章節"""
        if not hasattr(self, 'current_region_data') or not self.chapter_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的章節", parent=self.root)
            return

        selected_index = self.chapter_listbox.curselection()[0]
        chapter = self.current_region_data['chapters'][selected_index]
        chapter_id = chapter.get('chapter_id', '???')

        if not messagebox.askyesno("確認刪除", f"確定要刪除章節 {chapter_id} 嗎？\n此操作無法復原。", parent=self.root):
            return

        self.current_region_data['chapters'].pop(selected_index)
        self.save_data_to_file('regions')
        self.on_region_selected(None)

    def get_stage_name(self, stage_id):
        """從 stages.json 獲取關卡名稱"""
        stages_data = self.data_cache.get('stages', {})
        stages_list = stages_data.get('stages', [])
        for stage in stages_list:
            if stage.get('stage_id') == stage_id:
                return stage.get('stage_name', '')
        return None

    def add_stage_from_list(self):
        """從關卡列表中選擇並新增關卡"""
        if not hasattr(self, 'current_chapter_data'):
            return

        # 創建關卡選擇對話框
        stage_dialog = tk.Toplevel(self.root)
        stage_dialog.title("選擇關卡")
        stage_dialog.geometry("500x400")
        stage_dialog.transient(self.root)
        stage_dialog.grab_set()

        ttk.Label(stage_dialog, text="請選擇要添加的關卡:", font=("Noto Sans TC", 11)).pack(pady=10)

        # 關卡列表
        list_frame = ttk.Frame(stage_dialog)
        list_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

        stage_listbox = tk.Listbox(list_frame, height=15)
        stage_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        scrollbar = ttk.Scrollbar(list_frame, orient="vertical", command=stage_listbox.yview)
        stage_listbox.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 填入所有關卡
        stages_data = self.data_cache.get('stages', {})
        stages_list = stages_data.get('stages', [])

        # 獲取已經在章節中的關卡ID
        current_stage_ids = []
        for i in range(self.chapter_stages_listbox.size()):
            item_text = self.chapter_stages_listbox.get(i)
            stage_id = item_text.split(' - ')[0].strip()
            current_stage_ids.append(stage_id)

        for stage in stages_list:
            stage_id = stage.get('stage_id', '???')
            stage_name = stage.get('stage_name', '未命名')
            difficulty = stage.get('difficulty', 1)

            # 標記已添加的關卡
            if stage_id in current_stage_ids:
                display_text = f"{stage_id} - {stage_name} (難度:{difficulty}) [已添加]"
            else:
                display_text = f"{stage_id} - {stage_name} (難度:{difficulty})"

            stage_listbox.insert(tk.END, display_text)

        # 按鈕
        btn_frame = ttk.Frame(stage_dialog)
        btn_frame.pack(fill='x', padx=10, pady=10)

        def on_add():
            if not stage_listbox.curselection():
                messagebox.showerror("錯誤", "請先選擇一個關卡", parent=stage_dialog)
                return

            selected_index = stage_listbox.curselection()[0]
            selected_text = stage_listbox.get(selected_index)

            # 檢查是否已添加
            if "[已添加]" in selected_text:
                messagebox.showwarning("警告", "此關卡已經在列表中", parent=stage_dialog)
                return

            # 提取關卡ID和名稱
            parts = selected_text.split(' (難度:')[0]
            stage_id = parts.split(' - ')[0].strip()
            stage_name = parts.split(' - ')[1].strip() if ' - ' in parts else ''

            # 添加到章節關卡列表
            display_text = f"{stage_id} - {stage_name}" if stage_name else stage_id
            self.chapter_stages_listbox.insert(tk.END, display_text)

            stage_dialog.destroy()

        ttk.Button(btn_frame, text="添加", command=on_add, style='Accent.TButton').pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=stage_dialog.destroy).pack(side=tk.LEFT, padx=5)

    def add_stage_manually(self):
        """手動輸入關卡ID"""
        if not hasattr(self, 'current_chapter_data'):
            return

        stage_id = simpledialog.askstring("手動輸入關卡", "請輸入關卡ID (例如: STAGE_001):", parent=self.root)
        if not stage_id:
            return

        stage_id = stage_id.strip()

        # 嘗試獲取關卡名稱
        stage_name = self.get_stage_name(stage_id)
        display_text = f"{stage_id} - {stage_name}" if stage_name else stage_id

        # 檢查是否已存在
        for i in range(self.chapter_stages_listbox.size()):
            item_text = self.chapter_stages_listbox.get(i)
            existing_id = item_text.split(' - ')[0].strip()
            if existing_id == stage_id:
                messagebox.showwarning("警告", "此關卡已經在列表中", parent=self.root)
                return

        self.chapter_stages_listbox.insert(tk.END, display_text)

    def delete_chapter_stage(self):
        """刪除章節中的關卡"""
        if not hasattr(self, 'chapter_stages_listbox'):
            return

        if not self.chapter_stages_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的關卡", parent=self.root)
            return

        selected_index = self.chapter_stages_listbox.curselection()[0]
        self.chapter_stages_listbox.delete(selected_index)

    # ==================== 關卡管理標籤 ====================

    def populate_stages_tab(self):
        """建立「關卡管理」標籤頁的 UI（雙欄佈局：關卡列表 + 關卡詳情）"""
        self.clear_tab(self.tab_stages)

        stages_data = self.data_cache.get('stages', {})
        stages_list = stages_data.get('stages', [])

        if not isinstance(stages_list, list):
            ttk.Label(self.tab_stages, text="stages.json 格式錯誤或為空").pack()
            return

        # 主容器
        main_frame = ttk.Frame(self.tab_stages)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # --- 左側：關卡列表 ---
        left_frame = ttk.Frame(main_frame, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 5))
        left_frame.pack_propagate(False)

        ttk.Label(left_frame, text="關卡列表", font=("Noto Sans TC", 11, 'bold')).pack()

        stage_btn_frame = ttk.Frame(left_frame)
        stage_btn_frame.pack(fill='x', pady=5)
        ttk.Button(stage_btn_frame, text="新增", command=self.add_new_stage).pack(side=tk.LEFT, expand=True, fill='x')
        ttk.Button(stage_btn_frame, text="刪除", command=self.delete_stage).pack(side=tk.LEFT, expand=True, fill='x')

        self.stage_listbox = tk.Listbox(left_frame, exportselection=False)
        self.stage_listbox.pack(fill=tk.BOTH, expand=True)

        for stage in stages_list:
            stage_id = stage.get('stage_id', '???')
            stage_name = stage.get('stage_name', '未命名')
            difficulty = stage.get('difficulty', 1)
            self.stage_listbox.insert(tk.END, f"{stage_id} - {stage_name} (難度:{difficulty})")

        self.stage_listbox.bind('<<ListboxSelect>>', self.on_stage_selected)

        # --- 右側：關卡詳情 ---
        self.stage_detail_frame = ttk.Frame(main_frame)
        self.stage_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        ttk.Label(self.stage_detail_frame, text="請從左側選擇關卡進行編輯").pack(padx=20, pady=20)

    def on_stage_selected(self, event):
        """當選擇關卡時，顯示關卡詳情編輯表單"""
        if not self.stage_listbox.curselection():
            return

        selected_index = self.stage_listbox.curselection()[0]
        stages_list = self.data_cache['stages']['stages']
        self.current_stage_index = selected_index
        self.current_stage_data = stages_list[selected_index]

        # 清空並重建表單
        self.clear_tab(self.stage_detail_frame)

        # 創建可滾動的表單
        canvas = tk.Canvas(self.stage_detail_frame)
        scrollbar = ttk.Scrollbar(self.stage_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # ✅ 綁定鼠標滾輪
        self.bind_mousewheel(canvas)

        self.stage_widget_vars = {}

        # === 基本信息 ===
        ttk.Label(form_frame, text="基本信息", font=("Noto Sans TC", 12, 'bold')).pack(pady=10, anchor='w')

        self.create_stage_form_row(form_frame, "關卡ID", 'entry', 'stage_id')
        self.create_stage_form_row(form_frame, "關卡名稱", 'entry', 'stage_name')
        self.create_stage_form_row(form_frame, "描述", 'text', 'description')
        self.create_stage_form_row(form_frame, "難度", 'entry', 'difficulty')

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # === 前置關卡 ===
        ttk.Label(form_frame, text="前置關卡 (必須先通關)", font=("Noto Sans TC", 11, 'bold')).pack(pady=5, anchor='w')

        prereq_frame = ttk.Frame(form_frame)
        prereq_frame.pack(fill='x', pady=5)

        self.stage_prereq_listbox = tk.Listbox(prereq_frame, height=4)
        self.stage_prereq_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 載入現有前置關卡
        unlock_req = self.current_stage_data.get('unlock_requirements', {})
        required_stages = unlock_req.get('required_stages', [])
        for req_stage in required_stages:
            self.stage_prereq_listbox.insert(tk.END, req_stage)

        prereq_btn_frame = ttk.Frame(prereq_frame)
        prereq_btn_frame.pack(side=tk.LEFT, fill='y', padx=5)
        ttk.Button(prereq_btn_frame, text="新增", command=self.add_prerequisite_stage).pack(fill='x', pady=2)
        ttk.Button(prereq_btn_frame, text="編輯", command=self.edit_prerequisite_stage).pack(fill='x', pady=2)
        ttk.Button(prereq_btn_frame, text="刪除", command=self.delete_prerequisite_stage).pack(fill='x', pady=2)

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # === 波次配置 ===
        ttk.Label(form_frame, text="波次配置 (WAVES)", font=("Noto Sans TC", 11, 'bold')).pack(pady=5, anchor='w')

        # 波次列表
        waves_frame = ttk.Frame(form_frame)
        waves_frame.pack(fill='both', expand=True, pady=5)

        # 如果沒有 waves，從 enemies 創建單波
        if 'waves' not in self.current_stage_data or not self.current_stage_data['waves']:
            enemies = self.current_stage_data.get('enemies', [])
            if enemies:
                self.current_stage_data['waves'] = [{'wave_number': 1, 'enemies': enemies}]
            else:
                self.current_stage_data['waves'] = []

        self.waves_notebook = ttk.Notebook(waves_frame)
        self.waves_notebook.pack(fill='both', expand=True)

        # 為每個波次創建標籤頁
        for wave_idx, wave_data in enumerate(self.current_stage_data.get('waves', [])):
            self.create_wave_tab(wave_idx, wave_data)

        # 波次管理按鈕
        wave_btn_frame = ttk.Frame(form_frame)
        wave_btn_frame.pack(fill='x', pady=5)
        ttk.Button(wave_btn_frame, text="➕ 新增波次", command=self.add_new_wave).pack(side=tk.LEFT, padx=2)
        ttk.Button(wave_btn_frame, text="🗑️ 刪除當前波次", command=self.delete_current_wave).pack(side=tk.LEFT, padx=2)

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # === 獎勵配置 ===
        ttk.Label(form_frame, text="獎勵配置", font=("Noto Sans TC", 11, 'bold')).pack(pady=5, anchor='w')

        rewards = self.current_stage_data.get('rewards', {})

        # 金幣
        gold_frame = ttk.Frame(form_frame)
        gold_frame.pack(fill='x', pady=2)
        ttk.Label(gold_frame, text="金幣獎勵", width=15).pack(side=tk.LEFT)
        gold_var = tk.IntVar(value=rewards.get('gold', 0))
        ttk.Entry(gold_frame, textvariable=gold_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.stage_widget_vars['reward_gold'] = gold_var

        # 經驗值
        exp_frame = ttk.Frame(form_frame)
        exp_frame.pack(fill='x', pady=2)
        ttk.Label(exp_frame, text="經驗值獎勵", width=15).pack(side=tk.LEFT)
        exp_var = tk.IntVar(value=rewards.get('exp', 0))
        ttk.Entry(exp_frame, textvariable=exp_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.stage_widget_vars['reward_exp'] = exp_var

        # 卡片掉落
        ttk.Label(form_frame, text="卡片掉落配置", font=("Noto Sans TC", 10)).pack(anchor='w', pady=(10, 5))

        card_drops_frame = ttk.Frame(form_frame)
        card_drops_frame.pack(fill='both', expand=True)

        self.card_drops_listbox = tk.Listbox(card_drops_frame, height=5)
        self.card_drops_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 載入卡片掉落
        for card_drop in rewards.get('card_drops', []):
            card_id = card_drop.get('card_id', '???')
            drop_rate = card_drop.get('drop_rate', 0)
            self.card_drops_listbox.insert(tk.END, f"{card_id} (掉率: {drop_rate * 100}%)")

        card_drop_btn_frame = ttk.Frame(card_drops_frame)
        card_drop_btn_frame.pack(side=tk.LEFT, fill='y', padx=5)
        ttk.Button(card_drop_btn_frame, text="新增", command=self.add_card_drop).pack(fill='x', pady=2)
        ttk.Button(card_drop_btn_frame, text="編輯", command=self.edit_card_drop).pack(fill='x', pady=2)
        ttk.Button(card_drop_btn_frame, text="刪除", command=self.delete_card_drop).pack(fill='x', pady=2)

        # 保存按鈕
        save_frame = ttk.Frame(form_frame)
        save_frame.pack(fill='x', pady=10)
        ttk.Button(save_frame, text="💾 保存關卡", command=self.save_current_stage, style='Accent.TButton').pack(expand=True, fill='x')

    def create_stage_form_row(self, parent, label, widget_type, data_key):
        """創建關卡表單的一行"""
        row_frame = ttk.Frame(parent)
        row_frame.pack(fill='x', pady=2)
        ttk.Label(row_frame, text=label, width=15).pack(side=tk.LEFT)

        data_value = self.current_stage_data.get(data_key)

        if widget_type == 'entry':
            var = tk.StringVar(value=str(data_value) if data_value is not None else "")
            widget = ttk.Entry(row_frame, textvariable=var)
            widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.stage_widget_vars[data_key] = var

        elif widget_type == 'text':
            text_widget = tk.Text(row_frame, height=3, width=40)
            text_widget.insert('1.0', data_value or "")
            text_widget.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.stage_widget_vars[data_key] = text_widget

    def create_wave_tab(self, wave_idx, wave_data):
        """為單個波次創建編輯標籤頁"""
        wave_number = wave_data.get('wave_number', wave_idx + 1)
        wave_frame = ttk.Frame(self.waves_notebook)
        self.waves_notebook.add(wave_frame, text=f"第 {wave_number} 波")

        ttk.Label(wave_frame, text=f"第 {wave_number} 波敵人配置", font=("Noto Sans TC", 10, 'bold')).pack(pady=5)

        # 敵人列表
        enemy_list_frame = ttk.Frame(wave_frame)
        enemy_list_frame.pack(fill='both', expand=True, padx=10, pady=5)

        enemy_listbox = tk.Listbox(enemy_list_frame, height=8)
        enemy_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 載入敵人
        for enemy_config in wave_data.get('enemies', []):
            enemy_id = enemy_config.get('enemy_id', '???')
            count = enemy_config.get('count', 1)
            enemy_listbox.insert(tk.END, f"{enemy_id} x{count}")

        # 存儲引用
        if not hasattr(self, 'wave_enemy_listboxes'):
            self.wave_enemy_listboxes = {}
        self.wave_enemy_listboxes[wave_idx] = enemy_listbox

        # 按鈕
        enemy_btn_frame = ttk.Frame(enemy_list_frame)
        enemy_btn_frame.pack(side=tk.LEFT, fill='y', padx=5)
        ttk.Button(enemy_btn_frame, text="新增", command=lambda idx=wave_idx: self.add_enemy_to_wave(idx)).pack(fill='x', pady=2)
        ttk.Button(enemy_btn_frame, text="編輯", command=lambda idx=wave_idx: self.edit_enemy_in_wave(idx)).pack(fill='x', pady=2)
        ttk.Button(enemy_btn_frame, text="刪除", command=lambda idx=wave_idx: self.delete_enemy_from_wave(idx)).pack(fill='x', pady=2)

    def add_enemy_to_wave(self, wave_idx):
        """新增敵人到指定波次（使用選單選擇）"""
        # 獲取所有敵人列表
        enemies_data = self.data_cache.get('enemies', {})
        all_enemies = enemies_data.get('enemies', [])

        if not all_enemies:
            messagebox.showerror("錯誤", "找不到敵人數據！請先在「敵人管理」標籤中創建敵人。", parent=self.root)
            return

        # 創建彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("新增敵人")
        dialog.geometry("400x200")
        dialog.transient(self.root)
        dialog.grab_set()

        # 敵人選單
        ttk.Label(dialog, text="選擇敵人:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        enemy_var = tk.StringVar()
        enemy_options = []
        enemy_id_map = {}  # 顯示名稱 -> enemy_id

        for enemy in all_enemies:
            enemy_id = enemy.get('enemy_id', '???')
            enemy_name = enemy.get('enemy_name', '未命名')
            display_text = f"{enemy_id} - {enemy_name}"
            enemy_options.append(display_text)
            enemy_id_map[display_text] = enemy_id

        enemy_combo = ttk.Combobox(dialog, textvariable=enemy_var, values=enemy_options, state='readonly', width=40)
        enemy_combo.pack(pady=5, padx=20)
        if enemy_options:
            enemy_combo.current(0)

        # 數量輸入
        ttk.Label(dialog, text="數量:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)
        count_var = tk.IntVar(value=1)
        count_spin = ttk.Spinbox(dialog, from_=1, to=99, textvariable=count_var, width=10)
        count_spin.pack(pady=5, padx=20, anchor='w')

        # 按鈕
        def on_confirm():
            selected_text = enemy_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇敵人！", parent=dialog)
                return

            enemy_id = enemy_id_map[selected_text]
            count = count_var.get()

            # 添加到數據
            waves = self.current_stage_data.get('waves', [])
            if wave_idx < len(waves):
                if 'enemies' not in waves[wave_idx]:
                    waves[wave_idx]['enemies'] = []
                waves[wave_idx]['enemies'].append({'enemy_id': enemy_id, 'count': count})

                # 更新列表框
                if wave_idx in self.wave_enemy_listboxes:
                    listbox = self.wave_enemy_listboxes[wave_idx]
                    listbox.insert(tk.END, f"{enemy_id} x{count}")

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def edit_enemy_in_wave(self, wave_idx):
        """編輯波次中的敵人（修改敵人ID和數量）"""
        if wave_idx not in self.wave_enemy_listboxes:
            return

        listbox = self.wave_enemy_listboxes[wave_idx]
        if not listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要編輯的敵人", parent=self.root)
            return

        selected_index = listbox.curselection()[0]

        # 獲取當前敵人數據
        waves = self.current_stage_data.get('waves', [])
        if wave_idx >= len(waves):
            return

        enemies = waves[wave_idx].get('enemies', [])
        if selected_index >= len(enemies):
            return

        current_enemy = enemies[selected_index]
        current_enemy_id = current_enemy.get('enemy_id', '')
        current_count = current_enemy.get('count', 1)

        # 獲取所有敵人列表
        enemies_data = self.data_cache.get('enemies', {})
        all_enemies = enemies_data.get('enemies', [])

        if not all_enemies:
            messagebox.showerror("錯誤", "找不到敵人數據！", parent=self.root)
            return

        # 創建編輯彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("編輯敵人")
        dialog.geometry("400x200")
        dialog.transient(self.root)
        dialog.grab_set()

        # 敵人選單
        ttk.Label(dialog, text="選擇敵人:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        enemy_var = tk.StringVar()
        enemy_options = []
        enemy_id_map = {}  # 顯示名稱 -> enemy_id

        current_index = 0
        for i, enemy in enumerate(all_enemies):
            enemy_id = enemy.get('enemy_id', '???')
            enemy_name = enemy.get('enemy_name', '未命名')
            display_text = f"{enemy_id} - {enemy_name}"
            enemy_options.append(display_text)
            enemy_id_map[display_text] = enemy_id

            # 找到當前選中的敵人
            if enemy_id == current_enemy_id:
                current_index = i

        enemy_combo = ttk.Combobox(dialog, textvariable=enemy_var, values=enemy_options, state='readonly', width=40)
        enemy_combo.pack(pady=5, padx=20)
        if enemy_options:
            enemy_combo.current(current_index)

        # 數量輸入
        ttk.Label(dialog, text="數量:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)
        count_var = tk.IntVar(value=current_count)
        count_spin = ttk.Spinbox(dialog, from_=1, to=99, textvariable=count_var, width=10)
        count_spin.pack(pady=5, padx=20, anchor='w')

        # 按鈕
        def on_confirm():
            selected_text = enemy_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇敵人！", parent=dialog)
                return

            enemy_id = enemy_id_map[selected_text]
            count = count_var.get()

            # 更新數據
            enemies[selected_index] = {'enemy_id': enemy_id, 'count': count}

            # 更新列表框
            listbox.delete(selected_index)
            listbox.insert(selected_index, f"{enemy_id} x{count}")
            listbox.selection_set(selected_index)

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def delete_enemy_from_wave(self, wave_idx):
        """從指定波次刪除敵人"""
        if wave_idx not in self.wave_enemy_listboxes:
            return

        listbox = self.wave_enemy_listboxes[wave_idx]
        if not listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的敵人", parent=self.root)
            return

        selected_index = listbox.curselection()[0]

        # 從數據刪除
        waves = self.current_stage_data.get('waves', [])
        if wave_idx < len(waves):
            enemies = waves[wave_idx].get('enemies', [])
            if selected_index < len(enemies):
                enemies.pop(selected_index)

        # 從列表框刪除
        listbox.delete(selected_index)

    def add_new_wave(self):
        """新增波次"""
        if not hasattr(self, 'current_stage_data'):
            return

        waves = self.current_stage_data.get('waves', [])
        new_wave_number = len(waves) + 1

        new_wave = {
            'wave_number': new_wave_number,
            'enemies': []
        }

        waves.append(new_wave)
        self.current_stage_data['waves'] = waves

        # 重新載入關卡詳情
        self.on_stage_selected(None)
        self.stage_listbox.selection_set(self.current_stage_index)

    def delete_current_wave(self):
        """刪除當前波次"""
        if not hasattr(self, 'current_stage_data'):
            return

        if not hasattr(self, 'waves_notebook'):
            return

        current_tab = self.waves_notebook.index('current')
        waves = self.current_stage_data.get('waves', [])

        if current_tab >= len(waves):
            return

        if not messagebox.askyesno("確認刪除", f"確定要刪除第 {current_tab + 1} 波嗎？", parent=self.root):
            return

        waves.pop(current_tab)

        # 重新編號
        for idx, wave in enumerate(waves):
            wave['wave_number'] = idx + 1

        # 重新載入
        self.on_stage_selected(None)
        self.stage_listbox.selection_set(self.current_stage_index)

    def add_prerequisite_stage(self):
        """新增前置關卡（使用選單選擇）"""
        # 獲取所有關卡列表
        stages_data = self.data_cache.get('stages', {})
        all_stages = stages_data.get('stages', [])

        if not all_stages:
            messagebox.showerror("錯誤", "找不到關卡數據！", parent=self.root)
            return

        # 過濾掉當前關卡
        current_stage_id = self.current_stage_data.get('stage_id', '')
        available_stages = [s for s in all_stages if s.get('stage_id') != current_stage_id]

        if not available_stages:
            messagebox.showinfo("提示", "沒有可用的前置關卡", parent=self.root)
            return

        # 創建彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("新增前置關卡")
        dialog.geometry("400x150")
        dialog.transient(self.root)
        dialog.grab_set()

        # 關卡選單
        ttk.Label(dialog, text="選擇前置關卡:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        stage_var = tk.StringVar()
        stage_options = []
        stage_id_map = {}  # 顯示名稱 -> stage_id

        for stage in available_stages:
            stage_id = stage.get('stage_id', '???')
            stage_name = stage.get('stage_name', '未命名')
            display_text = f"{stage_id} - {stage_name}"
            stage_options.append(display_text)
            stage_id_map[display_text] = stage_id

        stage_combo = ttk.Combobox(dialog, textvariable=stage_var, values=stage_options, state='readonly', width=40)
        stage_combo.pack(pady=5, padx=20)
        if stage_options:
            stage_combo.current(0)

        # 按鈕
        def on_confirm():
            selected_text = stage_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇關卡！", parent=dialog)
                return

            stage_id = stage_id_map[selected_text]

            if 'unlock_requirements' not in self.current_stage_data:
                self.current_stage_data['unlock_requirements'] = {}

            if 'required_stages' not in self.current_stage_data['unlock_requirements']:
                self.current_stage_data['unlock_requirements']['required_stages'] = []

            # 檢查是否已存在
            if stage_id in self.current_stage_data['unlock_requirements']['required_stages']:
                messagebox.showwarning("警告", "該前置關卡已存在！", parent=dialog)
                return

            self.current_stage_data['unlock_requirements']['required_stages'].append(stage_id)
            self.stage_prereq_listbox.insert(tk.END, stage_id)

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def edit_prerequisite_stage(self):
        """編輯前置關卡"""
        if not self.stage_prereq_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要編輯的前置關卡", parent=self.root)
            return

        selected_index = self.stage_prereq_listbox.curselection()[0]

        # 獲取當前前置關卡
        unlock_req = self.current_stage_data.get('unlock_requirements', {})
        required_stages = unlock_req.get('required_stages', [])

        if selected_index >= len(required_stages):
            return

        current_stage_id = required_stages[selected_index]

        # 獲取所有關卡列表
        stages_data = self.data_cache.get('stages', {})
        all_stages = stages_data.get('stages', [])

        if not all_stages:
            messagebox.showerror("錯誤", "找不到關卡數據！", parent=self.root)
            return

        # 過濾掉當前關卡
        current_editing_stage_id = self.current_stage_data.get('stage_id', '')
        available_stages = [s for s in all_stages if s.get('stage_id') != current_editing_stage_id]

        if not available_stages:
            messagebox.showinfo("提示", "沒有可用的前置關卡", parent=self.root)
            return

        # 創建編輯彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("編輯前置關卡")
        dialog.geometry("400x150")
        dialog.transient(self.root)
        dialog.grab_set()

        # 關卡選單
        ttk.Label(dialog, text="選擇前置關卡:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        stage_var = tk.StringVar()
        stage_options = []
        stage_id_map = {}  # 顯示名稱 -> stage_id

        current_index = 0
        for i, stage in enumerate(available_stages):
            stage_id = stage.get('stage_id', '???')
            stage_name = stage.get('stage_name', '未命名')
            display_text = f"{stage_id} - {stage_name}"
            stage_options.append(display_text)
            stage_id_map[display_text] = stage_id

            # 找到當前選中的關卡
            if stage_id == current_stage_id:
                current_index = i

        stage_combo = ttk.Combobox(dialog, textvariable=stage_var, values=stage_options, state='readonly', width=40)
        stage_combo.pack(pady=5, padx=20)
        if stage_options:
            stage_combo.current(current_index)

        # 按鈕
        def on_confirm():
            selected_text = stage_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇關卡！", parent=dialog)
                return

            stage_id = stage_id_map[selected_text]

            # 更新數據
            required_stages[selected_index] = stage_id

            # 更新列表框
            self.stage_prereq_listbox.delete(selected_index)
            self.stage_prereq_listbox.insert(selected_index, stage_id)
            self.stage_prereq_listbox.selection_set(selected_index)

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def delete_prerequisite_stage(self):
        """刪除前置關卡"""
        if not self.stage_prereq_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的前置關卡", parent=self.root)
            return

        selected_index = self.stage_prereq_listbox.curselection()[0]

        unlock_req = self.current_stage_data.get('unlock_requirements', {})
        required_stages = unlock_req.get('required_stages', [])

        if selected_index < len(required_stages):
            required_stages.pop(selected_index)

        self.stage_prereq_listbox.delete(selected_index)

    def add_card_drop(self):
        """新增卡片掉落（使用選單選擇）"""
        # 獲取所有卡片列表
        cards_data = self.data_cache.get('cards', {})
        all_cards = cards_data.get('cards', [])

        if not all_cards:
            messagebox.showerror("錯誤", "找不到卡片數據！請先在「卡片管理」標籤中創建卡片。", parent=self.root)
            return

        # 創建彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("新增卡片掉落")
        dialog.geometry("450x200")
        dialog.transient(self.root)
        dialog.grab_set()

        # 卡片選單
        ttk.Label(dialog, text="選擇卡片:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        card_var = tk.StringVar()
        card_options = []
        card_id_map = {}  # 顯示名稱 -> card_id

        for card in all_cards:
            card_id = card.get('card_id', '???')
            card_name = card.get('card_name', '未命名')
            display_text = f"{card_id} - {card_name}"
            card_options.append(display_text)
            card_id_map[display_text] = card_id

        card_combo = ttk.Combobox(dialog, textvariable=card_var, values=card_options, state='readonly', width=45)
        card_combo.pack(pady=5, padx=20)
        if card_options:
            card_combo.current(0)

        # 掉落率輸入
        ttk.Label(dialog, text="掉落率 (0.0-1.0):", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)
        drop_rate_var = tk.DoubleVar(value=0.1)
        drop_rate_spin = ttk.Spinbox(dialog, from_=0.0, to=1.0, increment=0.05, textvariable=drop_rate_var, width=10, format="%.2f")
        drop_rate_spin.pack(pady=5, padx=20, anchor='w')

        # 按鈕
        def on_confirm():
            selected_text = card_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇卡片！", parent=dialog)
                return

            card_id = card_id_map[selected_text]
            drop_rate = drop_rate_var.get()

            if 'rewards' not in self.current_stage_data:
                self.current_stage_data['rewards'] = {}

            if 'card_drops' not in self.current_stage_data['rewards']:
                self.current_stage_data['rewards']['card_drops'] = []

            self.current_stage_data['rewards']['card_drops'].append({
                'card_id': card_id,
                'drop_rate': drop_rate
            })

            self.card_drops_listbox.insert(tk.END, f"{card_id} (掉率: {drop_rate * 100}%)")

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def edit_card_drop(self):
        """編輯卡片掉落"""
        if not self.card_drops_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要編輯的卡片掉落", parent=self.root)
            return

        selected_index = self.card_drops_listbox.curselection()[0]

        # 獲取當前卡片掉落數據
        rewards = self.current_stage_data.get('rewards', {})
        card_drops = rewards.get('card_drops', [])

        if selected_index >= len(card_drops):
            return

        current_drop = card_drops[selected_index]
        current_card_id = current_drop.get('card_id', '')
        current_drop_rate = current_drop.get('drop_rate', 0.1)

        # 獲取所有卡片列表
        cards_data = self.data_cache.get('cards', {})
        all_cards = cards_data.get('cards', [])

        if not all_cards:
            messagebox.showerror("錯誤", "找不到卡片數據！", parent=self.root)
            return

        # 創建編輯彈窗
        dialog = tk.Toplevel(self.root)
        dialog.title("編輯卡片掉落")
        dialog.geometry("450x200")
        dialog.transient(self.root)
        dialog.grab_set()

        # 卡片選單
        ttk.Label(dialog, text="選擇卡片:", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)

        card_var = tk.StringVar()
        card_options = []
        card_id_map = {}  # 顯示名稱 -> card_id

        current_index = 0
        for i, card in enumerate(all_cards):
            card_id = card.get('card_id', '???')
            card_name = card.get('card_name', '未命名')
            display_text = f"{card_id} - {card_name}"
            card_options.append(display_text)
            card_id_map[display_text] = card_id

            # 找到當前選中的卡片
            if card_id == current_card_id:
                current_index = i

        card_combo = ttk.Combobox(dialog, textvariable=card_var, values=card_options, state='readonly', width=45)
        card_combo.pack(pady=5, padx=20)
        if card_options:
            card_combo.current(current_index)

        # 掉落率輸入
        ttk.Label(dialog, text="掉落率 (0.0-1.0):", font=("Noto Sans TC", 10)).pack(pady=10, anchor='w', padx=20)
        drop_rate_var = tk.DoubleVar(value=current_drop_rate)
        drop_rate_spin = ttk.Spinbox(dialog, from_=0.0, to=1.0, increment=0.05, textvariable=drop_rate_var, width=10, format="%.2f")
        drop_rate_spin.pack(pady=5, padx=20, anchor='w')

        # 按鈕
        def on_confirm():
            selected_text = card_var.get()
            if not selected_text:
                messagebox.showerror("錯誤", "請選擇卡片！", parent=dialog)
                return

            card_id = card_id_map[selected_text]
            drop_rate = drop_rate_var.get()

            # 更新數據
            card_drops[selected_index] = {'card_id': card_id, 'drop_rate': drop_rate}

            # 更新列表框
            self.card_drops_listbox.delete(selected_index)
            self.card_drops_listbox.insert(selected_index, f"{card_id} (掉率: {drop_rate * 100}%)")
            self.card_drops_listbox.selection_set(selected_index)

            dialog.destroy()

        btn_frame = ttk.Frame(dialog)
        btn_frame.pack(pady=20)
        ttk.Button(btn_frame, text="確定", command=on_confirm).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="取消", command=dialog.destroy).pack(side=tk.LEFT, padx=5)

    def delete_card_drop(self):
        """刪除卡片掉落"""
        if not self.card_drops_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的卡片掉落", parent=self.root)
            return

        selected_index = self.card_drops_listbox.curselection()[0]

        rewards = self.current_stage_data.get('rewards', {})
        card_drops = rewards.get('card_drops', [])

        if selected_index < len(card_drops):
            card_drops.pop(selected_index)

        self.card_drops_listbox.delete(selected_index)

    def save_current_stage(self):
        """保存當前關卡"""
        if not hasattr(self, 'current_stage_data'):
            return

        # 更新基本信息
        self.current_stage_data['stage_id'] = self.stage_widget_vars['stage_id'].get()
        self.current_stage_data['stage_name'] = self.stage_widget_vars['stage_name'].get()
        self.current_stage_data['description'] = self.stage_widget_vars['description'].get('1.0', 'end-1c')

        # 更新難度
        try:
            self.current_stage_data['difficulty'] = int(self.stage_widget_vars['difficulty'].get())
        except ValueError:
            self.current_stage_data['difficulty'] = 1

        # 更新獎勵
        if 'rewards' not in self.current_stage_data:
            self.current_stage_data['rewards'] = {}

        self.current_stage_data['rewards']['gold'] = self.stage_widget_vars['reward_gold'].get()
        self.current_stage_data['rewards']['exp'] = self.stage_widget_vars['reward_exp'].get()

        # ✅ 刪除舊版 enemies 字段（現在統一使用 waves）
        if 'enemies' in self.current_stage_data:
            del self.current_stage_data['enemies']

        # 保存到文件
        self.save_data_to_file('stages')

        # 更新列表顯示
        self.populate_stages_tab()
        self.stage_listbox.selection_set(self.current_stage_index)
        self.on_stage_selected(None)

        messagebox.showinfo("成功", "關卡已保存", parent=self.root)

    def add_new_stage(self):
        """新增關卡"""
        stage_id = simpledialog.askstring("新增關卡", "請輸入關卡ID (例如: STAGE_001):", parent=self.root)
        if not stage_id:
            return

        stage_name = simpledialog.askstring("新增關卡", "請輸入關卡名稱:", parent=self.root)
        if not stage_name:
            return

        new_stage = {
            "stage_id": stage_id.strip(),
            "stage_name": stage_name.strip(),
            "description": "",
            "difficulty": 1,
            "waves": [
                {
                    "wave_number": 1,
                    "enemies": []
                }
            ],
            "rewards": {
                "gold": 100,
                "exp": 50,
                "card_drops": []
            },
            "unlock_requirements": {
                "required_stages": []
            }
        }

        self.data_cache['stages']['stages'].append(new_stage)
        self.save_data_to_file('stages')
        self.populate_stages_tab()
        messagebox.showinfo("成功", f"關卡 {stage_id} 已新增", parent=self.root)

    def delete_stage(self):
        """刪除選中的關卡"""
        if not self.stage_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的關卡", parent=self.root)
            return

        selected_index = self.stage_listbox.curselection()[0]
        stage = self.data_cache['stages']['stages'][selected_index]
        stage_id = stage.get('stage_id', '???')

        if not messagebox.askyesno("確認刪除", f"確定要刪除關卡 {stage_id} 嗎？\n此操作無法復原。", parent=self.root):
            return

        self.data_cache['stages']['stages'].pop(selected_index)
        self.save_data_to_file('stages')
        self.populate_stages_tab()

    # ========== 商城系統管理 ==========
    def populate_shop_items_tab(self):
        """填充商城物品管理標籤"""
        self.clear_tab(self.tab_shop_items)
        shop_data = self.data_cache.get('shop_items')
        if not shop_data or 'items' not in shop_data:
            ttk.Label(self.tab_shop_items, text="shop_items.json 格式錯誤或為空").pack()
            return

        # 左側：物品列表
        left_frame = ttk.Frame(self.tab_shop_items, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        ttk.Label(left_frame, text="商城物品列表", style='Title.TLabel').pack(pady=(0,5))

        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x', pady=5)
        ttk.Button(btn_frame, text="新增物品", command=self.add_shop_item).pack(side=tk.LEFT, expand=True, fill='x', padx=2)
        ttk.Button(btn_frame, text="刪除物品", command=self.delete_shop_item).pack(side=tk.LEFT, expand=True, fill='x', padx=2)

        self.shop_items_listbox = tk.Listbox(left_frame, exportselection=False)
        self.shop_items_listbox.pack(fill=tk.BOTH, expand=True)

        for item in shop_data['items']:
            self.shop_items_listbox.insert(tk.END, f"{item.get('id', '???')} - {item.get('name', 'N/A')}")

        self.shop_items_listbox.bind('<<ListboxSelect>>', self.on_shop_item_selected)

        # 右側：編輯區
        self.shop_item_detail_frame = ttk.Frame(self.tab_shop_items)
        self.shop_item_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.shop_item_detail_frame, text="請從左側列表選擇一個物品進行編輯").pack(padx=20, pady=20)

    def on_shop_item_selected(self, event):
        """選中商城物品"""
        if not self.shop_items_listbox.curselection():
            return

        selected_index = self.shop_items_listbox.curselection()[0]
        item_data = self.data_cache['shop_items']['items'][selected_index]
        self.current_shop_item_index = selected_index

        self.clear_tab(self.shop_item_detail_frame)
        self.shop_item_vars = {}

        canvas = tk.Canvas(self.shop_item_detail_frame)
        scrollbar = ttk.Scrollbar(self.shop_item_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.bind_mousewheel(canvas)

        def create_row(label, key, widget_type='entry'):
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text=label, width=15).pack(side=tk.LEFT)
            value = item_data.get(key, '')
            if widget_type == 'entry':
                var = tk.StringVar(value=value)
                ttk.Entry(row, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.shop_item_vars[key] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(value or 0))
                ttk.Spinbox(row, from_=0, to=999999, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.shop_item_vars[key] = var
            elif widget_type == 'combo':
                var = tk.StringVar(value=value)
                ttk.Combobox(row, textvariable=var, values=['gold', 'gem'], state='readonly').pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.shop_item_vars[key] = var
            elif widget_type == 'text':
                text = tk.Text(row, height=3, width=40)
                text.insert('1.0', value)
                text.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.shop_item_vars[key] = text

        # 獲取所有卡片 {card_id: card_name}
        all_cards = {}
        if self.data_cache.get('cards'):
            for card in self.data_cache['cards'].get('cards', []):
                all_cards[card['card_id']] = card.get('card_name', card['card_id'])

        ttk.Label(form_frame, text="【基本信息】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_row("物品ID", "id")
        create_row("名稱", "name")
        create_row("描述", "description", 'text')
        create_row("分類", "category")
        create_row("價格", "price", 'spinbox')
        create_row("貨幣類型", "currency", 'combo')
        create_row("購買上限", "purchase_limit", 'spinbox')
        create_row("獎勵類型", "reward_type")

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)
        ttk.Label(form_frame, text="【獎勵配置 reward_config】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))

        reward_config = item_data.get('reward_config', {})
        reward_type = item_data.get('reward_type', 'currency')
        self.shop_item_vars['reward_config'] = {}

        if reward_type == 'bundle':
            # 禮包類型 - 可包含多個獎勵
            bundle_frame = ttk.LabelFrame(form_frame, text="禮包內容", padding=10)
            bundle_frame.pack(fill='both', expand=True, pady=5)

            rewards_list_frame = ttk.Frame(bundle_frame)
            rewards_list_frame.pack(side=tk.LEFT, fill='both', expand=True, padx=5)
            ttk.Label(rewards_list_frame, text="獎勵列表:").pack(anchor='w')

            rewards_listbox = tk.Listbox(rewards_list_frame, height=10, exportselection=False)
            rewards_listbox.pack(fill='both', expand=True)

            # 載入現有獎勵
            current_rewards = reward_config.get('rewards', [])
            for reward in current_rewards:
                display_text = self._format_reward_display(reward, all_cards)
                rewards_listbox.insert(tk.END, display_text)

            self.shop_item_vars['reward_config']['rewards'] = (rewards_listbox, current_rewards[:])

            # 按鈕區
            btn_frame = ttk.Frame(bundle_frame)
            btn_frame.pack(side=tk.LEFT, fill='y', padx=5)

            def add_reward():
                # 選擇獎勵類型對話框
                dialog = tk.Toplevel(self.root)
                dialog.title("添加獎勵")
                dialog.geometry("450x350")

                ttk.Label(dialog, text="選擇獎勵類型:", font=('', 10, 'bold')).pack(pady=5)

                reward_type_var = tk.StringVar(value='currency')
                ttk.Radiobutton(dialog, text="貨幣 (金幣/鑽石)", variable=reward_type_var, value='currency').pack(anchor='w', padx=20)
                ttk.Radiobutton(dialog, text="指定卡片", variable=reward_type_var, value='specific_card').pack(anchor='w', padx=20)
                ttk.Radiobutton(dialog, text="背包擴充", variable=reward_type_var, value='bag_expansion').pack(anchor='w', padx=20)
                ttk.Radiobutton(dialog, text="道具", variable=reward_type_var, value='item').pack(anchor='w', padx=20)

                params_frame = ttk.Frame(dialog)
                params_frame.pack(fill='both', expand=True, padx=20, pady=10)

                param_widgets = {}

                def update_params(*args):
                    # 清空參數框
                    for widget in params_frame.winfo_children():
                        widget.destroy()
                    param_widgets.clear()

                    rtype = reward_type_var.get()
                    if rtype == 'currency':
                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="貨幣類型:").pack(side=tk.LEFT)
                        currency_var = tk.StringVar(value='gold')
                        ttk.Combobox(row, textvariable=currency_var, values=['gold', 'gem'], state='readonly').pack(side=tk.LEFT, padx=5)
                        param_widgets['currency_type'] = currency_var

                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="數量:").pack(side=tk.LEFT)
                        amount_var = tk.IntVar(value=100)
                        ttk.Spinbox(row, from_=1, to=999999, textvariable=amount_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['amount'] = amount_var

                    elif rtype == 'specific_card':
                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="選擇卡片:").pack(side=tk.LEFT)
                        card_var = tk.StringVar()
                        card_combo = ttk.Combobox(row, textvariable=card_var, values=[f"{name} ({cid})" for cid, name in sorted(all_cards.items(), key=lambda x: x[1])], state='readonly')
                        card_combo.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['card_id'] = card_var

                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="數量:").pack(side=tk.LEFT)
                        count_var = tk.IntVar(value=1)
                        ttk.Spinbox(row, from_=1, to=999, textvariable=count_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['count'] = count_var

                    elif rtype == 'bag_expansion':
                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="增加格數:").pack(side=tk.LEFT)
                        slots_var = tk.IntVar(value=5)
                        ttk.Spinbox(row, from_=1, to=999, textvariable=slots_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['slots'] = slots_var

                    elif rtype == 'item':
                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="道具類型:").pack(side=tk.LEFT)
                        item_type_var = tk.StringVar(value='gacha_ticket')
                        ttk.Entry(row, textvariable=item_type_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['item_type'] = item_type_var

                        row = ttk.Frame(params_frame)
                        row.pack(fill='x', pady=2)
                        ttk.Label(row, text="數量:").pack(side=tk.LEFT)
                        count_var = tk.IntVar(value=1)
                        ttk.Spinbox(row, from_=1, to=999, textvariable=count_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                        param_widgets['count'] = count_var

                reward_type_var.trace('w', update_params)
                update_params()

                def confirm():
                    new_reward = {'type': reward_type_var.get()}
                    for key, var in param_widgets.items():
                        value = var.get()
                        if key == 'card_id' and '(' in value:
                            # 提取卡片ID
                            value = value.split('(')[-1].rstrip(')')
                        new_reward[key] = value

                    self.shop_item_vars['reward_config']['rewards'][1].append(new_reward)
                    display_text = self._format_reward_display(new_reward, all_cards)
                    rewards_listbox.insert(tk.END, display_text)
                    dialog.destroy()

                ttk.Button(dialog, text="確定", command=confirm).pack(pady=10)

            def remove_reward():
                sel = rewards_listbox.curselection()
                if sel:
                    idx = sel[0]
                    self.shop_item_vars['reward_config']['rewards'][1].pop(idx)
                    rewards_listbox.delete(idx)

            ttk.Button(btn_frame, text="➕ 添加獎勵", command=add_reward, width=12).pack(pady=2)
            ttk.Button(btn_frame, text="➖ 移除獎勵", command=remove_reward, width=12).pack(pady=2)

        elif reward_type == 'specific_card':
            # 單卡類型
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="卡片ID", width=15).pack(side=tk.LEFT)
            card_id_var = tk.StringVar(value=reward_config.get('card_id', ''))
            card_combo = ttk.Combobox(row, textvariable=card_id_var, values=[f"{name} ({cid})" for cid, name in sorted(all_cards.items(), key=lambda x: x[1])], state='readonly')
            card_combo.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            # 如果有現有值，設置顯示
            current_card_id = reward_config.get('card_id', '')
            if current_card_id and current_card_id in all_cards:
                card_combo.set(f"{all_cards[current_card_id]} ({current_card_id})")
            self.shop_item_vars['reward_config']['card_id'] = card_id_var

            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="數量", width=15).pack(side=tk.LEFT)
            count_var = tk.IntVar(value=reward_config.get('count', 1))
            ttk.Spinbox(row, from_=1, to=999, textvariable=count_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.shop_item_vars['reward_config']['count'] = count_var

        elif reward_type == 'currency':
            # 貨幣類型
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="貨幣類型", width=15).pack(side=tk.LEFT)
            currency_type_var = tk.StringVar(value=reward_config.get('currency_type', 'gold'))
            ttk.Combobox(row, textvariable=currency_type_var, values=['gold', 'gem'], state='readonly').pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.shop_item_vars['reward_config']['currency_type'] = currency_type_var

            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="數量", width=15).pack(side=tk.LEFT)
            amount_var = tk.IntVar(value=reward_config.get('amount', 100))
            ttk.Spinbox(row, from_=1, to=999999, textvariable=amount_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.shop_item_vars['reward_config']['amount'] = amount_var

        elif reward_type == 'item':
            # 道具類型
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="道具類型", width=15).pack(side=tk.LEFT)
            item_type_var = tk.StringVar(value=reward_config.get('item_type', ''))
            ttk.Entry(row, textvariable=item_type_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.shop_item_vars['reward_config']['item_type'] = item_type_var

            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text="數量", width=15).pack(side=tk.LEFT)
            count_var = tk.IntVar(value=reward_config.get('count', 1))
            ttk.Spinbox(row, from_=1, to=999, textvariable=count_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
            self.shop_item_vars['reward_config']['count'] = count_var

        ttk.Button(form_frame, text="儲存變更", command=self.save_shop_item, style='Accent.TButton').pack(pady=20)

    def _format_reward_display(self, reward, all_cards):
        """格式化獎勵顯示文字"""
        rtype = reward.get('type', '')
        if rtype == 'currency':
            currency = '金幣' if reward.get('currency_type') == 'gold' else '鑽石'
            return f"💰 {currency} x{reward.get('amount', 0)}"
        elif rtype == 'specific_card':
            card_id = reward.get('card_id', '')
            card_name = all_cards.get(card_id, card_id)
            return f"🃏 {card_name} ({card_id}) x{reward.get('count', 1)}"
        elif rtype == 'bag_expansion':
            return f"📦 背包擴充 +{reward.get('slots', 0)} 格"
        elif rtype == 'item':
            return f"🎁 {reward.get('item_type', '???')} x{reward.get('count', 1)}"
        else:
            return str(reward)

    def save_shop_item(self):
        """儲存商城物品"""
        if not hasattr(self, 'current_shop_item_index'):
            return

        item = self.data_cache['shop_items']['items'][self.current_shop_item_index]

        # 保存基本欄位
        for key, var in self.shop_item_vars.items():
            if key == 'reward_config':
                # 獎勵配置特殊處理
                if 'reward_config' not in item:
                    item['reward_config'] = {}

                reward_type = item.get('reward_type', 'currency')
                if reward_type == 'bundle':
                    # 禮包類型 - 保存獎勵列表
                    if 'rewards' in var:
                        item['reward_config']['rewards'] = var['rewards'][1]
                else:
                    # 其他類型 - 保存各個欄位
                    for sub_key, sub_var in var.items():
                        if sub_key != 'rewards':
                            value = sub_var.get()
                            # 如果是卡片ID，提取括號內的ID
                            if sub_key == 'card_id' and '(' in value:
                                value = value.split('(')[-1].rstrip(')')
                            item['reward_config'][sub_key] = value
            elif isinstance(var, tk.Text):
                item[key] = var.get('1.0', 'end-1c')
            else:
                item[key] = var.get()

        self.save_data_to_file('shop_items')
        self.populate_shop_items_tab()
        self.shop_items_listbox.selection_set(self.current_shop_item_index)
        messagebox.showinfo("成功", "物品已保存", parent=self.root)

    def add_shop_item(self):
        """新增商城物品"""
        item_id = simpledialog.askstring("新增物品", "請輸入物品ID:", parent=self.root)
        if not item_id:
            return

        new_item = {
            "id": item_id,
            "name": "新物品",
            "description": "",
            "price": 100,
            "currency": "gold",
            "category": "items",
            "icon": "",
            "reward_type": "currency",
            "purchase_limit": 0,
            "reward_config": {}
        }

        self.data_cache['shop_items']['items'].append(new_item)
        self.save_data_to_file('shop_items')
        self.populate_shop_items_tab()
        messagebox.showinfo("成功", f"物品 {item_id} 已新增", parent=self.root)

    def delete_shop_item(self):
        """刪除商城物品"""
        if not self.shop_items_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的物品", parent=self.root)
            return

        selected_index = self.shop_items_listbox.curselection()[0]
        item = self.data_cache['shop_items']['items'][selected_index]

        if messagebox.askyesno("確認", f"確定刪除物品 {item.get('id')} 嗎？", parent=self.root):
            self.data_cache['shop_items']['items'].pop(selected_index)
            self.save_data_to_file('shop_items')
            self.populate_shop_items_tab()

    # ========== 抽卡系統管理 ==========
    def populate_gacha_pools_tab(self):
        """填充抽卡池管理標籤"""
        self.clear_tab(self.tab_gacha_pools)
        gacha_data = self.data_cache.get('gacha_pools')
        if not gacha_data or 'pools' not in gacha_data:
            ttk.Label(self.tab_gacha_pools, text="gacha_pools.json 格式錯誤或為空").pack()
            return

        # 左側：卡池列表
        left_frame = ttk.Frame(self.tab_gacha_pools, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        ttk.Label(left_frame, text="抽卡池列表", style='Title.TLabel').pack(pady=(0,5))

        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x', pady=5)
        ttk.Button(btn_frame, text="新增卡池", command=self.add_gacha_pool).pack(side=tk.LEFT, expand=True, fill='x', padx=2)
        ttk.Button(btn_frame, text="刪除卡池", command=self.delete_gacha_pool).pack(side=tk.LEFT, expand=True, fill='x', padx=2)

        self.gacha_pools_listbox = tk.Listbox(left_frame, exportselection=False)
        self.gacha_pools_listbox.pack(fill=tk.BOTH, expand=True)

        for pool in gacha_data['pools']:
            self.gacha_pools_listbox.insert(tk.END, f"{pool.get('id', '???')} - {pool.get('name', 'N/A')}")

        self.gacha_pools_listbox.bind('<<ListboxSelect>>', self.on_gacha_pool_selected)

        # 右側：編輯區
        self.gacha_pool_detail_frame = ttk.Frame(self.tab_gacha_pools)
        self.gacha_pool_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.gacha_pool_detail_frame, text="請從左側列表選擇一個卡池進行編輯").pack(padx=20, pady=20)

    def on_gacha_pool_selected(self, event):
        """選中抽卡池"""
        if not self.gacha_pools_listbox.curselection():
            return

        selected_index = self.gacha_pools_listbox.curselection()[0]
        pool_data = self.data_cache['gacha_pools']['pools'][selected_index]
        self.current_gacha_pool_index = selected_index

        self.clear_tab(self.gacha_pool_detail_frame)
        self.gacha_pool_vars = {}
        self.gacha_pool_card_lists = {}

        canvas = tk.Canvas(self.gacha_pool_detail_frame)
        scrollbar = ttk.Scrollbar(self.gacha_pool_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.bind_mousewheel(canvas)

        def create_row(label, key, widget_type='entry'):
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text=label, width=20).pack(side=tk.LEFT)
            value = pool_data.get(key, '')
            if widget_type == 'entry':
                var = tk.StringVar(value=value)
                ttk.Entry(row, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.gacha_pool_vars[key] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(value or 0))
                ttk.Spinbox(row, from_=0, to=99999, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.gacha_pool_vars[key] = var
            elif widget_type == 'float':
                var = tk.DoubleVar(value=float(value or 0.0))
                ttk.Spinbox(row, from_=0.0, to=1.0, increment=0.01, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.gacha_pool_vars[key] = var
            elif widget_type == 'text':
                text = tk.Text(row, height=3, width=40)
                text.insert('1.0', value)
                text.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.gacha_pool_vars[key] = text

        # 獲取所有卡片 {card_id: card_name}
        all_cards = {}
        if self.data_cache.get('cards'):
            for card in self.data_cache['cards'].get('cards', []):
                all_cards[card['card_id']] = card.get('card_name', card['card_id'])

        def create_card_selector(label, key, is_array=True):
            """創建卡片選擇器（顯示卡名）"""
            section = ttk.LabelFrame(form_frame, text=label, padding=10)
            section.pack(fill='both', expand=True, pady=5)

            # 當前選中的卡片列表
            selected_frame = ttk.Frame(section)
            selected_frame.pack(side=tk.LEFT, fill='both', expand=True, padx=5)
            ttk.Label(selected_frame, text="已選擇的卡片:").pack(anchor='w')

            selected_listbox = tk.Listbox(selected_frame, height=8, exportselection=False)
            selected_listbox.pack(fill='both', expand=True)

            # 載入已選卡片
            if is_array:
                current_cards = pool_data.get(key, [])
            else:
                card_pool = pool_data.get('card_pool', {})
                current_cards = card_pool.get(key, [])

            for card_id in current_cards:
                card_name = all_cards.get(card_id, card_id)
                selected_listbox.insert(tk.END, f"{card_name} ({card_id})")

            self.gacha_pool_card_lists[key] = (selected_listbox, current_cards[:])

            # 按鈕區
            btn_frame = ttk.Frame(section)
            btn_frame.pack(side=tk.LEFT, fill='y', padx=5)

            def add_card():
                # 顯示所有可選卡片
                dialog = tk.Toplevel(self.root)
                dialog.title("選擇卡片")
                dialog.geometry("400x500")

                ttk.Label(dialog, text="選擇要添加的卡片:", font=('', 10, 'bold')).pack(pady=5)

                search_frame = ttk.Frame(dialog)
                search_frame.pack(fill='x', padx=10, pady=5)
                ttk.Label(search_frame, text="搜尋:").pack(side=tk.LEFT)
                search_var = tk.StringVar()
                search_entry = ttk.Entry(search_frame, textvariable=search_var)
                search_entry.pack(side=tk.LEFT, fill='x', expand=True, padx=5)

                card_listbox = tk.Listbox(dialog, exportselection=False)
                card_listbox.pack(fill='both', expand=True, padx=10, pady=5)

                # 填充所有卡片
                all_card_items = []
                for cid, cname in sorted(all_cards.items(), key=lambda x: x[1]):
                    item = f"{cname} ({cid})"
                    all_card_items.append((cid, item))
                    card_listbox.insert(tk.END, item)

                def filter_cards(*args):
                    query = search_var.get().lower()
                    card_listbox.delete(0, tk.END)
                    for cid, item in all_card_items:
                        if query in item.lower():
                            card_listbox.insert(tk.END, item)

                search_var.trace('w', filter_cards)

                def confirm():
                    sel = card_listbox.curselection()
                    if sel:
                        selected_text = card_listbox.get(sel[0])
                        # 提取卡片ID
                        card_id = selected_text.split('(')[-1].rstrip(')')
                        if card_id not in self.gacha_pool_card_lists[key][1]:
                            self.gacha_pool_card_lists[key][1].append(card_id)
                            card_name = all_cards.get(card_id, card_id)
                            selected_listbox.insert(tk.END, f"{card_name} ({card_id})")
                        dialog.destroy()

                ttk.Button(dialog, text="確定", command=confirm).pack(pady=10)

            def remove_card():
                sel = selected_listbox.curselection()
                if sel:
                    idx = sel[0]
                    self.gacha_pool_card_lists[key][1].pop(idx)
                    selected_listbox.delete(idx)

            ttk.Button(btn_frame, text="➕ 添加卡片", command=add_card, width=12).pack(pady=2)
            ttk.Button(btn_frame, text="➖ 移除卡片", command=remove_card, width=12).pack(pady=2)

        ttk.Label(form_frame, text="【基本信息】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_row("卡池ID", "id")
        create_row("名稱", "name")
        create_row("描述", "description", 'text')
        create_row("圖標顏色", "icon_color")

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        ttk.Label(form_frame, text="【抽卡設置】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_row("傳說掉率", "legendary_rate", 'float')
        create_row("史詩掉率", "epic_rate", 'float')
        create_row("稀有掉率", "rare_rate", 'float')
        create_row("保底抽數", "pity_threshold", 'spinbox')
        create_row("單抽費用", "single_pull_cost", 'spinbox')
        create_row("十連費用", "ten_pull_cost", 'spinbox')
        create_row("貨幣類型", "currency")

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        ttk.Label(form_frame, text="【卡片配置】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_card_selector("✨ 展示卡片 (showcase_cards)", "showcase_cards", is_array=True)
        create_card_selector("🔶 傳說級卡池 (legendary)", "legendary", is_array=False)
        create_card_selector("🔷 史詩級卡池 (epic)", "epic", is_array=False)
        create_card_selector("🔹 稀有級卡池 (rare)", "rare", is_array=False)
        create_card_selector("⚪ 普通級卡池 (common)", "common", is_array=False)

        ttk.Button(form_frame, text="儲存變更", command=self.save_gacha_pool, style='Accent.TButton').pack(pady=20)

    def save_gacha_pool(self):
        """儲存抽卡池"""
        if not hasattr(self, 'current_gacha_pool_index'):
            return

        pool = self.data_cache['gacha_pools']['pools'][self.current_gacha_pool_index]

        # 保存基本欄位
        for key, var in self.gacha_pool_vars.items():
            if isinstance(var, tk.Text):
                pool[key] = var.get('1.0', 'end-1c')
            else:
                pool[key] = var.get()

        # 保存卡片列表
        if hasattr(self, 'gacha_pool_card_lists'):
            for key, (listbox, card_list) in self.gacha_pool_card_lists.items():
                if key == "showcase_cards":
                    # showcase_cards 是頂層數組
                    pool[key] = card_list
                else:
                    # legendary/epic/rare/common 在 card_pool 下
                    if 'card_pool' not in pool:
                        pool['card_pool'] = {}
                    pool['card_pool'][key] = card_list

        self.save_data_to_file('gacha_pools')
        self.populate_gacha_pools_tab()
        self.gacha_pools_listbox.selection_set(self.current_gacha_pool_index)
        messagebox.showinfo("成功", "卡池已保存", parent=self.root)

    def add_gacha_pool(self):
        """新增抽卡池"""
        pool_id = simpledialog.askstring("新增卡池", "請輸入卡池ID:", parent=self.root)
        if not pool_id:
            return

        new_pool = {
            "id": pool_id,
            "name": "新卡池",
            "description": "",
            "icon_color": "#4A90E2",
            "showcase_cards": [],
            "legendary_rate": 0.01,
            "epic_rate": 0.05,
            "rare_rate": 0.20,
            "pity_threshold": 90,
            "single_pull_cost": 1,
            "ten_pull_cost": 10,
            "currency": "gem",
            "card_pool": {}
        }

        self.data_cache['gacha_pools']['pools'].append(new_pool)
        self.save_data_to_file('gacha_pools')
        self.populate_gacha_pools_tab()
        messagebox.showinfo("成功", f"卡池 {pool_id} 已新增", parent=self.root)

    def delete_gacha_pool(self):
        """刪除抽卡池"""
        if not self.gacha_pools_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的卡池", parent=self.root)
            return

        selected_index = self.gacha_pools_listbox.curselection()[0]
        pool = self.data_cache['gacha_pools']['pools'][selected_index]

        if messagebox.askyesno("確認", f"確定刪除卡池 {pool.get('id')} 嗎？", parent=self.root):
            self.data_cache['gacha_pools']['pools'].pop(selected_index)
            self.save_data_to_file('gacha_pools')
            self.populate_gacha_pools_tab()

    # ========== 訓練室管理 ==========
    def populate_training_rooms_tab(self):
        """填充訓練室管理標籤"""
        self.clear_tab(self.tab_training_rooms)
        training_data = self.data_cache.get('training_rooms')
        if not training_data or 'training_rooms' not in training_data:
            ttk.Label(self.tab_training_rooms, text="training_rooms.json 格式錯誤或為空").pack()
            return

        # 左側：訓練室列表
        left_frame = ttk.Frame(self.tab_training_rooms, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        ttk.Label(left_frame, text="訓練室列表", style='Title.TLabel').pack(pady=(0,5))

        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x', pady=5)
        ttk.Button(btn_frame, text="新增訓練室", command=self.add_training_room).pack(side=tk.LEFT, expand=True, fill='x', padx=2)
        ttk.Button(btn_frame, text="刪除訓練室", command=self.delete_training_room).pack(side=tk.LEFT, expand=True, fill='x', padx=2)

        self.training_rooms_listbox = tk.Listbox(left_frame, exportselection=False)
        self.training_rooms_listbox.pack(fill=tk.BOTH, expand=True)

        for room in training_data['training_rooms']:
            self.training_rooms_listbox.insert(tk.END, f"{room.get('room_id', '???')} - {room.get('room_name', 'N/A')}")

        self.training_rooms_listbox.bind('<<ListboxSelect>>', self.on_training_room_selected)

        # 右側：編輯區
        self.training_room_detail_frame = ttk.Frame(self.tab_training_rooms)
        self.training_room_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.training_room_detail_frame, text="請從左側列表選擇一個訓練室進行編輯").pack(padx=20, pady=20)

    def on_training_room_selected(self, event):
        """選中訓練室"""
        if not self.training_rooms_listbox.curselection():
            return

        selected_index = self.training_rooms_listbox.curselection()[0]
        room_data = self.data_cache['training_rooms']['training_rooms'][selected_index]
        self.current_training_room_index = selected_index

        self.clear_tab(self.training_room_detail_frame)
        self.training_room_vars = {}

        canvas = tk.Canvas(self.training_room_detail_frame)
        scrollbar = ttk.Scrollbar(self.training_room_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)
        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.bind_mousewheel(canvas)

        def create_row(label, key, widget_type='entry'):
            row = ttk.Frame(form_frame)
            row.pack(fill='x', pady=2)
            ttk.Label(row, text=label, width=20).pack(side=tk.LEFT)
            value = room_data.get(key, '')
            if widget_type == 'entry':
                var = tk.StringVar(value=value)
                ttk.Entry(row, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.training_room_vars[key] = var
            elif widget_type == 'spinbox':
                var = tk.IntVar(value=int(value or 0))
                ttk.Spinbox(row, from_=0, to=99999, textvariable=var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.training_room_vars[key] = var
            elif widget_type == 'bool':
                var = tk.BooleanVar(value=bool(value))
                ttk.Checkbutton(row, variable=var).pack(side=tk.LEFT, padx=5)
                self.training_room_vars[key] = var
            elif widget_type == 'text':
                text = tk.Text(row, height=3, width=40)
                text.insert('1.0', value)
                text.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
                self.training_room_vars[key] = text

        ttk.Label(form_frame, text="【基本信息】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_row("訓練室ID", "room_id")
        create_row("名稱", "room_name")
        create_row("描述", "room_desc", 'text')
        create_row("圖標", "room_icon")

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        ttk.Label(form_frame, text="【訓練設置】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))
        create_row("訓練時間(秒)", "training_time", 'spinbox')
        create_row("經驗值獎勵", "exp_reward", 'spinbox')
        create_row("最大隊伍數", "max_teams", 'spinbox')
        create_row("預設解鎖", "is_unlocked_by_default", 'bool')

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=5)
        ttk.Label(form_frame, text="【解鎖條件】", font=('', 10, 'bold')).pack(anchor='w', pady=(5,0))

        # 解鎖條件
        unlock_cond = room_data.get('unlock_conditions', {})
        self.training_room_vars['unlock_conditions'] = {}

        # 解鎖類型
        row = ttk.Frame(form_frame)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text="解鎖類型", width=20).pack(side=tk.LEFT)
        unlock_type_var = tk.StringVar(value=unlock_cond.get('type', 'default'))
        unlock_type_combo = ttk.Combobox(row, textvariable=unlock_type_var, values=['default', 'gold', 'diamond', 'stage'], state='readonly')
        unlock_type_combo.pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.training_room_vars['unlock_conditions']['type'] = unlock_type_var

        # 金幣費用
        row = ttk.Frame(form_frame)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text="金幣費用", width=20).pack(side=tk.LEFT)
        cost_gold_var = tk.IntVar(value=int(unlock_cond.get('cost_gold', 0)))
        ttk.Spinbox(row, from_=0, to=999999, textvariable=cost_gold_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.training_room_vars['unlock_conditions']['cost_gold'] = cost_gold_var

        # 鑽石費用
        row = ttk.Frame(form_frame)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text="鑽石費用", width=20).pack(side=tk.LEFT)
        cost_diamond_var = tk.IntVar(value=int(unlock_cond.get('cost_diamond', 0)))
        ttk.Spinbox(row, from_=0, to=999999, textvariable=cost_diamond_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.training_room_vars['unlock_conditions']['cost_diamond'] = cost_diamond_var

        # 需要關卡
        row = ttk.Frame(form_frame)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text="需要通關關卡", width=20).pack(side=tk.LEFT)
        required_stage_var = tk.StringVar(value=unlock_cond.get('required_stage', ''))
        ttk.Entry(row, textvariable=required_stage_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.training_room_vars['unlock_conditions']['required_stage'] = required_stage_var

        # 需要玩家等級
        row = ttk.Frame(form_frame)
        row.pack(fill='x', pady=2)
        ttk.Label(row, text="需要玩家等級", width=20).pack(side=tk.LEFT)
        required_level_var = tk.IntVar(value=int(unlock_cond.get('required_player_level', 1)))
        ttk.Spinbox(row, from_=1, to=999, textvariable=required_level_var).pack(side=tk.LEFT, fill='x', expand=True, padx=5)
        self.training_room_vars['unlock_conditions']['required_player_level'] = required_level_var

        ttk.Button(form_frame, text="儲存變更", command=self.save_training_room, style='Accent.TButton').pack(pady=20)

    def save_training_room(self):
        """儲存訓練室"""
        if not hasattr(self, 'current_training_room_index'):
            return

        room = self.data_cache['training_rooms']['training_rooms'][self.current_training_room_index]

        # 保存基本欄位
        for key, var in self.training_room_vars.items():
            if key == 'unlock_conditions':
                # 解鎖條件特殊處理
                if 'unlock_conditions' not in room:
                    room['unlock_conditions'] = {}
                for sub_key, sub_var in var.items():
                    room['unlock_conditions'][sub_key] = sub_var.get()
            elif isinstance(var, tk.Text):
                room[key] = var.get('1.0', 'end-1c')
            else:
                room[key] = var.get()

        self.save_data_to_file('training_rooms')
        self.populate_training_rooms_tab()
        self.training_rooms_listbox.selection_set(self.current_training_room_index)
        messagebox.showinfo("成功", "訓練室已保存", parent=self.root)

    def add_training_room(self):
        """新增訓練室"""
        room_id = simpledialog.askstring("新增訓練室", "請輸入訓練室ID:", parent=self.root)
        if not room_id:
            return

        new_room = {
            "room_id": room_id,
            "room_name": "新訓練室",
            "room_desc": "",
            "room_icon": "📚",
            "training_time": 30,
            "exp_reward": 300,
            "max_teams": 1,
            "unlock_conditions": {
                "type": "default",
                "cost_gold": 0,
                "cost_diamond": 0,
                "required_stage": "",
                "required_player_level": 1
            },
            "is_unlocked_by_default": True
        }

        self.data_cache['training_rooms']['training_rooms'].append(new_room)
        self.save_data_to_file('training_rooms')
        self.populate_training_rooms_tab()
        messagebox.showinfo("成功", f"訓練室 {room_id} 已新增", parent=self.root)

    def delete_training_room(self):
        """刪除訓練室"""
        if not self.training_rooms_listbox.curselection():
            messagebox.showerror("錯誤", "請先選擇要刪除的訓練室", parent=self.root)
            return

        selected_index = self.training_rooms_listbox.curselection()[0]
        room = self.data_cache['training_rooms']['training_rooms'][selected_index]

        if messagebox.askyesno("確認", f"確定刪除訓練室 {room.get('room_id')} 嗎？", parent=self.root):
            self.data_cache['training_rooms']['training_rooms'].pop(selected_index)
            self.save_data_to_file('training_rooms')
            self.populate_training_rooms_tab()


# --- 程式進入點 ---
if __name__ == "__main__":
    main_window = tk.Tk()
    app = GameEditorApp(main_window)
    main_window.mainloop()