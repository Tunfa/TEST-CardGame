#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
對話任務編輯器 (Dialog & Task Editor)
專門用於編輯遊戲的對話和任務系統

功能：
1. 對話編輯 (dialogs.json)
2. 任務編輯 (quests.json)
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, simpledialog
import json
import os
from functools import partial
import copy


class DialogTaskEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("對話任務編輯器 - Dialog & Task Editor")
        self.root.geometry("1400x900")

        # 數據快取
        self.data_cache = {}
        self.data_dir = None

        # 當前選擇
        self.current_dialog_id = None
        self.current_quest_id = None

        # Widget 變數
        self.widget_vars = {}

        # ✅ Action 類型選項（帶說明）
        self.ACTION_TYPES = {
            "next": "next - 繼續到下一段對話",
            "close": "close - 關閉對話框",
            "show_card_selection": "show_card_selection - 顯示卡片選擇界面",
            "highlight_training_area": "highlight_training_area - 高亮訓練區域",
            "claim_reward": "claim_reward - 領取獎勵",
            "go_to_scene": "go_to_scene - 前往指定場景"
        }

        # ✅ Quest 類型選項（帶說明）
        self.QUEST_TYPES = {
            "tutorial": "tutorial - 新手教學",
            "main": "main - 主線任務",
            "side": "side - 支線任務",
            "daily": "daily - 每日任務",
            "achievement": "achievement - 成就任務"
        }

        # ✅ Condition 類型選項（帶說明）
        self.CONDITION_TYPES = {
            "dialog_completed": "dialog_completed - 對話完成",
            "card_selected": "card_selected - 卡片已選擇",
            "scene_entered": "scene_entered - 進入指定場景",
            "training_completed": "training_completed - 訓練完成",
            "quest_completed": "quest_completed - 任務完成",
            "card_count": "card_count - 卡片數量達到要求",
            "gold_amount": "gold_amount - 金幣數量達到要求",
            "custom": "custom - 自定義事件（需配合 event 參數）"
        }

        # 建立 UI
        self.create_menu()
        self.create_main_ui()
        self.create_status_bar()

    # ========== UI 建立 ==========

    def create_menu(self):
        """建立選單列"""
        menu_bar = tk.Menu(self.root)

        # 檔案選單
        file_menu = tk.Menu(menu_bar, tearoff=0)
        file_menu.add_command(label="設定 data 資料夾...", command=self.select_data_directory)
        file_menu.add_separator()
        file_menu.add_command(label="重新載入", command=self.reload_data)
        file_menu.add_separator()
        file_menu.add_command(label="退出", command=self.root.quit)
        menu_bar.add_cascade(label="檔案", menu=file_menu)

        self.root.config(menu=menu_bar)

    def create_main_ui(self):
        """建立主要 UI"""
        # 建立分頁
        self.notebook = ttk.Notebook(self.root)

        self.tab_dialogs = ttk.Frame(self.notebook)
        self.tab_quests = ttk.Frame(self.notebook)

        self.notebook.add(self.tab_dialogs, text='對話編輯 (Dialogs)', state="disabled")
        self.notebook.add(self.tab_quests, text='任務編輯 (Quests)', state="disabled")

        self.notebook.pack(expand=True, fill='both', padx=10, pady=10)
        self.notebook.pack_forget()

        # 佔位標籤
        self.placeholder_label = ttk.Label(
            self.root,
            text="歡迎使用對話任務編輯器\n\n請從 [檔案] -> [設定 data 資料夾...] 載入您的遊戲專案",
            font=("Arial", 14),
            justify=tk.CENTER
        )
        self.placeholder_label.pack(expand=True, fill='both', padx=20, pady=20)

    def create_status_bar(self):
        """建立狀態列"""
        self.status_var = tk.StringVar()
        self.status_var.set("準備就緒。請從 [檔案] 選單載入資料夾。")
        status_bar = ttk.Label(self.root, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        status_bar.pack(side=tk.BOTTOM, fill=tk.X)

    # ========== 資料夾管理 ==========

    def select_data_directory(self):
        """選擇資料夾"""
        chosen_dir = filedialog.askdirectory(title="選擇遊戲的 data 資料夾")
        if not chosen_dir:
            return

        self.data_dir = chosen_dir
        self.load_all_data()

    def load_all_data(self):
        """載入所有 JSON 數據"""
        if not self.data_dir:
            return

        config_dir = os.path.join(self.data_dir, "config")
        if not os.path.exists(config_dir):
            messagebox.showerror("錯誤", f"找不到 config 資料夾：{config_dir}")
            return

        # 載入對話
        dialogs_path = os.path.join(config_dir, "dialogs.json")
        if os.path.exists(dialogs_path):
            with open(dialogs_path, 'r', encoding='utf-8') as f:
                self.data_cache['dialogs'] = json.load(f)
        else:
            self.data_cache['dialogs'] = {"dialogs": []}

        # 載入任務
        quests_path = os.path.join(config_dir, "quests.json")
        if os.path.exists(quests_path):
            with open(quests_path, 'r', encoding='utf-8') as f:
                self.data_cache['quests'] = json.load(f)
        else:
            self.data_cache['quests'] = {"quests": []}

        # 顯示 notebook 並填充數據
        self.placeholder_label.pack_forget()
        self.notebook.pack(expand=True, fill='both', padx=10, pady=10)

        # 啟用分頁
        self.notebook.tab(self.tab_dialogs, state="normal")
        self.notebook.tab(self.tab_quests, state="normal")

        # 填充 UI
        self.populate_dialogs_tab()
        self.populate_quests_tab()

        self.status_var.set(f"已載入：{config_dir}")

    def reload_data(self):
        """重新載入數據"""
        if self.data_dir:
            self.load_all_data()
            messagebox.showinfo("成功", "數據已重新載入")

    def save_data_to_file(self, data_key):
        """儲存數據到 JSON 檔案"""
        if not self.data_dir:
            return

        config_dir = os.path.join(self.data_dir, "config")
        file_path = os.path.join(config_dir, f"{data_key}.json")

        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(self.data_cache[data_key], f, ensure_ascii=False, indent=2)
            self.status_var.set(f"✅ {data_key}.json 已儲存")
        except Exception as e:
            messagebox.showerror("儲存錯誤", f"無法儲存檔案：{e}")
            self.status_var.set(f"❌ {data_key}.json 儲存失敗")

    # ========== 對話編輯 ==========

    def populate_dialogs_tab(self):
        """填充對話編輯分頁"""
        # 清空
        for widget in self.tab_dialogs.winfo_children():
            widget.destroy()

        # 雙欄佈局
        left_frame = ttk.Frame(self.tab_dialogs, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        # 按鈕
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x', pady=(0, 5))
        ttk.Button(btn_frame, text="新增對話", command=self.add_new_dialog).pack(side=tk.LEFT, expand=True, fill='x', padx=(0, 2))
        ttk.Button(btn_frame, text="刪除選定", command=self.delete_current_dialog).pack(side=tk.LEFT, expand=True, fill='x', padx=(2, 0))

        # 列表
        self.dialog_listbox = tk.Listbox(left_frame, exportselection=False)
        self.dialog_listbox.pack(fill=tk.BOTH, expand=True)

        for dialog in self.data_cache['dialogs']['dialogs']:
            self.dialog_listbox.insert(tk.END, f"{dialog['dialog_id']}")

        self.dialog_listbox.bind('<<ListboxSelect>>', self.on_dialog_selected)

        # 右側詳細面板
        self.dialog_detail_frame = ttk.Frame(self.tab_dialogs)
        self.dialog_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.dialog_detail_frame, text="請從左側列表選擇一個對話進行編輯").pack(padx=20, pady=20)

    def on_dialog_selected(self, event):
        """當選擇對話時"""
        if not self.dialog_listbox.curselection():
            return

        selected_index = self.dialog_listbox.curselection()[0]
        selected_dialog = self.data_cache['dialogs']['dialogs'][selected_index]
        self.current_dialog_id = selected_dialog['dialog_id']

        # 清空右側面板
        for widget in self.dialog_detail_frame.winfo_children():
            widget.destroy()

        self.widget_vars = {}

        # 建立捲動區域
        canvas = tk.Canvas(self.dialog_detail_frame)
        scrollbar = ttk.Scrollbar(self.dialog_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)

        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 綁定滾輪
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

        # 建立表單
        ttk.Label(form_frame, text="對話 ID", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        dialog_id_var = tk.StringVar(value=selected_dialog['dialog_id'])
        ttk.Entry(form_frame, textvariable=dialog_id_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['dialog_id'] = dialog_id_var

        ttk.Label(form_frame, text="說話者", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        speaker_var = tk.StringVar(value=selected_dialog.get('speaker', ''))
        ttk.Entry(form_frame, textvariable=speaker_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['speaker'] = speaker_var

        ttk.Label(form_frame, text="說話者頭像", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        avatar_var = tk.StringVar(value=selected_dialog.get('speaker_avatar', ''))
        ttk.Entry(form_frame, textvariable=avatar_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['speaker_avatar'] = avatar_var

        ttk.Label(form_frame, text="對話內容", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        content_text = tk.Text(form_frame, height=6, wrap=tk.WORD)
        content_text.insert(tk.END, selected_dialog.get('content', ''))
        content_text.pack(fill='x', pady=(0, 10))
        self.widget_vars['content'] = content_text

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # 選項 (Choices)
        ttk.Label(form_frame, text="對話選項 (Choices)", font=("Arial", 11, "bold")).pack(anchor='w', pady=(5, 0))

        choices_frame = ttk.Frame(form_frame)
        choices_frame.pack(fill='x', pady=(0, 10))

        choices_listbox = tk.Listbox(choices_frame, height=4, exportselection=False)
        choices_listbox.pack(side=tk.LEFT, fill='both', expand=True, padx=(0, 5))

        for choice in selected_dialog.get('choices', []):
            choices_listbox.insert(tk.END, f"{choice.get('text', '')} -> {choice.get('action', '')}")

        self.widget_vars['choices_listbox'] = choices_listbox
        self.widget_vars['choices_data'] = selected_dialog.get('choices', []).copy()  # ✅ 使用 copy

        # 選項按鈕
        choice_btn_frame = ttk.Frame(choices_frame)
        choice_btn_frame.pack(side=tk.LEFT)

        ttk.Button(choice_btn_frame, text="新增", command=lambda: self.add_choice(choices_listbox)).pack(pady=2, fill='x')
        ttk.Button(choice_btn_frame, text="編輯", command=lambda: self.edit_choice(choices_listbox)).pack(pady=2, fill='x')
        ttk.Button(choice_btn_frame, text="刪除", command=lambda: self.remove_choice(choices_listbox)).pack(pady=2, fill='x')

        # 儲存按鈕
        ttk.Button(form_frame, text="💾 儲存此對話", command=self.save_current_dialog).pack(pady=20, fill='x')

    def add_choice(self, listbox):
        """新增選項"""
        dialog = ChoiceEditorDialog(self.root, self.ACTION_TYPES)
        self.root.wait_window(dialog)  # ✅ 等待彈窗關閉
        if dialog.result:
            self.widget_vars['choices_data'].append(dialog.result)
            listbox.insert(tk.END, f"{dialog.result['text']} -> {dialog.result['action']}")
            print(f"✅ 新增選項: {dialog.result}")

    def edit_choice(self, listbox):
        """編輯選項"""
        if not listbox.curselection():
            messagebox.showwarning("提示", "請先選擇一個選項")
            return

        idx = listbox.curselection()[0]
        current_choice = self.widget_vars['choices_data'][idx]

        dialog = ChoiceEditorDialog(self.root, self.ACTION_TYPES, current_choice)
        self.root.wait_window(dialog)  # ✅ 等待彈窗關閉
        if dialog.result:
            self.widget_vars['choices_data'][idx] = dialog.result
            listbox.delete(idx)
            listbox.insert(idx, f"{dialog.result['text']} -> {dialog.result['action']}")
            listbox.select_set(idx)  # ✅ 重新選中
            print(f"✅ 編輯選項: {dialog.result}")

    def remove_choice(self, listbox):
        """刪除選項"""
        if not listbox.curselection():
            messagebox.showwarning("提示", "請先選擇一個選項")
            return

        idx = listbox.curselection()[0]
        self.widget_vars['choices_data'].pop(idx)
        listbox.delete(idx)

    def save_current_dialog(self):
        """儲存當前對話"""
        if not self.current_dialog_id:
            return

        # 找到對話
        dialog_to_update = None
        for dialog in self.data_cache['dialogs']['dialogs']:
            if dialog['dialog_id'] == self.current_dialog_id:
                dialog_to_update = dialog
                break

        if not dialog_to_update:
            return

        # 更新數據
        dialog_to_update['dialog_id'] = self.widget_vars['dialog_id'].get()
        dialog_to_update['speaker'] = self.widget_vars['speaker'].get()
        dialog_to_update['speaker_avatar'] = self.widget_vars['speaker_avatar'].get()
        dialog_to_update['content'] = self.widget_vars['content'].get("1.0", tk.END).strip()
        dialog_to_update['choices'] = self.widget_vars['choices_data']

        # 更新 ID
        self.current_dialog_id = dialog_to_update['dialog_id']

        # 儲存到檔案
        self.save_data_to_file('dialogs')

        # 更新列表
        self.populate_dialogs_tab()
        messagebox.showinfo("成功", "對話已儲存！")

    def add_new_dialog(self):
        """新增對話"""
        new_id = simpledialog.askstring("新增對話", "請輸入新對話的 ID:", parent=self.root)
        if not new_id:
            return

        # 檢查重複
        for dialog in self.data_cache['dialogs']['dialogs']:
            if dialog['dialog_id'] == new_id:
                messagebox.showerror("錯誤", "此 ID 已存在！")
                return

        # 新增
        new_dialog = {
            "dialog_id": new_id,
            "speaker": "???",
            "speaker_avatar": "mystery",
            "content": "新對話內容",
            "choices": [
                {"text": "繼續", "action": "next"}
            ]
        }

        self.data_cache['dialogs']['dialogs'].append(new_dialog)
        self.save_data_to_file('dialogs')
        self.populate_dialogs_tab()

    def delete_current_dialog(self):
        """刪除當前對話"""
        if not self.dialog_listbox.curselection():
            return

        idx = self.dialog_listbox.curselection()[0]
        dialog_id = self.data_cache['dialogs']['dialogs'][idx]['dialog_id']

        if not messagebox.askyesno("確認", f"確定要刪除對話 {dialog_id} 嗎？"):
            return

        self.data_cache['dialogs']['dialogs'].pop(idx)
        self.save_data_to_file('dialogs')
        self.populate_dialogs_tab()

    # ========== 任務編輯 ==========

    def populate_quests_tab(self):
        """填充任務編輯分頁"""
        # 清空
        for widget in self.tab_quests.winfo_children():
            widget.destroy()

        # 雙欄佈局
        left_frame = ttk.Frame(self.tab_quests, width=300)
        left_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0), pady=10)
        left_frame.pack_propagate(False)

        # 按鈕
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill='x', pady=(0, 5))
        ttk.Button(btn_frame, text="新增任務", command=self.add_new_quest).pack(side=tk.LEFT, expand=True, fill='x', padx=(0, 2))
        ttk.Button(btn_frame, text="刪除選定", command=self.delete_current_quest).pack(side=tk.LEFT, expand=True, fill='x', padx=(2, 0))

        # 列表
        self.quest_listbox = tk.Listbox(left_frame, exportselection=False)
        self.quest_listbox.pack(fill=tk.BOTH, expand=True)

        for quest in self.data_cache['quests']['quests']:
            self.quest_listbox.insert(tk.END, f"{quest['quest_id']} - {quest['quest_name']}")

        self.quest_listbox.bind('<<ListboxSelect>>', self.on_quest_selected)

        # 右側詳細面板
        self.quest_detail_frame = ttk.Frame(self.tab_quests)
        self.quest_detail_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        ttk.Label(self.quest_detail_frame, text="請從左側列表選擇一個任務進行編輯").pack(padx=20, pady=20)

    def on_quest_selected(self, event):
        """當選擇任務時"""
        if not self.quest_listbox.curselection():
            return

        selected_index = self.quest_listbox.curselection()[0]
        selected_quest = self.data_cache['quests']['quests'][selected_index]
        self.current_quest_id = selected_quest['quest_id']

        # 清空右側面板
        for widget in self.quest_detail_frame.winfo_children():
            widget.destroy()

        self.widget_vars = {}

        # 建立捲動區域
        canvas = tk.Canvas(self.quest_detail_frame)
        scrollbar = ttk.Scrollbar(self.quest_detail_frame, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)

        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 綁定滾輪
        def _on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", _on_mousewheel)

        # 基本資訊
        ttk.Label(form_frame, text="任務 ID", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        quest_id_var = tk.StringVar(value=selected_quest['quest_id'])
        ttk.Entry(form_frame, textvariable=quest_id_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['quest_id'] = quest_id_var

        ttk.Label(form_frame, text="任務名稱", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        quest_name_var = tk.StringVar(value=selected_quest['quest_name'])
        ttk.Entry(form_frame, textvariable=quest_name_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['quest_name'] = quest_name_var

        ttk.Label(form_frame, text="任務描述", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        quest_desc_text = tk.Text(form_frame, height=3, wrap=tk.WORD)
        quest_desc_text.insert(tk.END, selected_quest.get('quest_desc', ''))
        quest_desc_text.pack(fill='x', pady=(0, 10))
        self.widget_vars['quest_desc'] = quest_desc_text

        ttk.Label(form_frame, text="任務類型", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        quest_type_var = tk.StringVar(value=selected_quest.get('quest_type', 'tutorial'))
        # ✅ 顯示帶說明的選項
        quest_type_combo = ttk.Combobox(form_frame, textvariable=quest_type_var,
                                        values=list(self.QUEST_TYPES.values()), state='readonly')
        quest_type_combo.pack(fill='x', pady=(0, 10))
        self.widget_vars['quest_type'] = quest_type_var
        self.widget_vars['quest_type_combo'] = quest_type_combo

        # 布林選項
        is_mandatory_var = tk.BooleanVar(value=selected_quest.get('is_mandatory', False))
        ttk.Checkbutton(form_frame, text="必須完成 (is_mandatory)", variable=is_mandatory_var).pack(anchor='w', pady=5)
        self.widget_vars['is_mandatory'] = is_mandatory_var

        auto_start_var = tk.BooleanVar(value=selected_quest.get('auto_start', False))
        ttk.Checkbutton(form_frame, text="自動開始 (auto_start)", variable=auto_start_var).pack(anchor='w', pady=5)
        self.widget_vars['auto_start'] = auto_start_var

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # 任務步驟
        ttk.Label(form_frame, text="任務步驟 (Steps)", font=("Arial", 11, "bold")).pack(anchor='w', pady=(5, 0))

        steps_frame = ttk.Frame(form_frame)
        steps_frame.pack(fill='x', pady=(0, 10))

        steps_listbox = tk.Listbox(steps_frame, height=6, exportselection=False)
        steps_listbox.pack(side=tk.LEFT, fill='both', expand=True, padx=(0, 5))

        for step in selected_quest.get('steps', []):
            steps_listbox.insert(tk.END, f"{step.get('step_id', '')} - {step.get('description', step.get('step_desc', ''))}")

        self.widget_vars['steps_listbox'] = steps_listbox
        self.widget_vars['steps_data'] = selected_quest.get('steps', []).copy()  # ✅ 使用 copy

        # 步驟按鈕
        step_btn_frame = ttk.Frame(steps_frame)
        step_btn_frame.pack(side=tk.LEFT)

        ttk.Button(step_btn_frame, text="新增", command=lambda: self.add_step(steps_listbox)).pack(pady=2, fill='x')
        ttk.Button(step_btn_frame, text="編輯", command=lambda: self.edit_step(steps_listbox)).pack(pady=2, fill='x')
        ttk.Button(step_btn_frame, text="刪除", command=lambda: self.remove_step(steps_listbox)).pack(pady=2, fill='x')
        ttk.Button(step_btn_frame, text="上移", command=lambda: self.move_step_up(steps_listbox)).pack(pady=2, fill='x')
        ttk.Button(step_btn_frame, text="下移", command=lambda: self.move_step_down(steps_listbox)).pack(pady=2, fill='x')

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # 獎勵
        ttk.Label(form_frame, text="獎勵 (Rewards)", font=("Arial", 11, "bold")).pack(anchor='w', pady=(5, 0))

        rewards = selected_quest.get('rewards', {})

        reward_frame = ttk.Frame(form_frame)
        reward_frame.pack(fill='x', pady=(0, 10))

        ttk.Label(reward_frame, text="金幣:").grid(row=0, column=0, sticky='w', padx=(0, 5))
        gold_var = tk.IntVar(value=rewards.get('gold', 0))
        ttk.Spinbox(reward_frame, from_=0, to=999999, textvariable=gold_var, width=15).grid(row=0, column=1, sticky='w')
        self.widget_vars['reward_gold'] = gold_var

        ttk.Label(reward_frame, text="鑽石:").grid(row=1, column=0, sticky='w', padx=(0, 5), pady=(5, 0))
        diamond_var = tk.IntVar(value=rewards.get('diamond', 0))
        ttk.Spinbox(reward_frame, from_=0, to=999999, textvariable=diamond_var, width=15).grid(row=1, column=1, sticky='w', pady=(5, 0))
        self.widget_vars['reward_diamond'] = diamond_var

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # 下一個任務
        ttk.Label(form_frame, text="下一個任務 (next_quest)", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        next_quest_var = tk.StringVar(value=selected_quest.get('next_quest', ''))
        ttk.Entry(form_frame, textvariable=next_quest_var).pack(fill='x', pady=(0, 10))
        self.widget_vars['next_quest'] = next_quest_var

        # 儲存按鈕
        ttk.Button(form_frame, text="💾 儲存此任務", command=self.save_current_quest).pack(pady=20, fill='x')

    def add_step(self, listbox):
        """新增步驟"""
        dialog = StepEditorDialog(self.root, self.CONDITION_TYPES)
        self.root.wait_window(dialog)  # ✅ 等待彈窗關閉
        if dialog.result:
            self.widget_vars['steps_data'].append(dialog.result)
            listbox.insert(tk.END, f"{dialog.result['step_id']} - {dialog.result.get('description', dialog.result.get('step_desc', ''))}")
            print(f"✅ 新增步驟: {dialog.result}")

    def edit_step(self, listbox):
        """編輯步驟"""
        if not listbox.curselection():
            messagebox.showwarning("提示", "請先選擇一個步驟")
            return

        idx = listbox.curselection()[0]
        current_step = self.widget_vars['steps_data'][idx]

        dialog = StepEditorDialog(self.root, self.CONDITION_TYPES, current_step)
        self.root.wait_window(dialog)  # ✅ 等待彈窗關閉
        if dialog.result:
            self.widget_vars['steps_data'][idx] = dialog.result
            listbox.delete(idx)
            listbox.insert(idx, f"{dialog.result['step_id']} - {dialog.result.get('description', dialog.result.get('step_desc', ''))}")
            listbox.select_set(idx)  # ✅ 重新選中
            print(f"✅ 編輯步驟: {dialog.result}")

    def remove_step(self, listbox):
        """刪除步驟"""
        if not listbox.curselection():
            messagebox.showwarning("提示", "請先選擇一個步驟")
            return

        idx = listbox.curselection()[0]
        self.widget_vars['steps_data'].pop(idx)
        listbox.delete(idx)

    def move_step_up(self, listbox):
        """上移步驟"""
        if not listbox.curselection():
            return

        idx = listbox.curselection()[0]
        if idx == 0:
            return

        # 交換
        self.widget_vars['steps_data'][idx], self.widget_vars['steps_data'][idx-1] = \
            self.widget_vars['steps_data'][idx-1], self.widget_vars['steps_data'][idx]

        # 更新 listbox
        listbox.delete(idx)
        listbox.delete(idx-1)
        listbox.insert(idx-1, f"{self.widget_vars['steps_data'][idx-1]['step_id']} - {self.widget_vars['steps_data'][idx-1].get('description', self.widget_vars['steps_data'][idx-1].get('step_desc', ''))}")
        listbox.insert(idx, f"{self.widget_vars['steps_data'][idx]['step_id']} - {self.widget_vars['steps_data'][idx].get('description', self.widget_vars['steps_data'][idx].get('step_desc', ''))}")
        listbox.select_set(idx-1)

    def move_step_down(self, listbox):
        """下移步驟"""
        if not listbox.curselection():
            return

        idx = listbox.curselection()[0]
        if idx >= len(self.widget_vars['steps_data']) - 1:
            return

        # 交換
        self.widget_vars['steps_data'][idx], self.widget_vars['steps_data'][idx+1] = \
            self.widget_vars['steps_data'][idx+1], self.widget_vars['steps_data'][idx]

        # 更新 listbox
        listbox.delete(idx)
        listbox.delete(idx)
        listbox.insert(idx, f"{self.widget_vars['steps_data'][idx]['step_id']} - {self.widget_vars['steps_data'][idx].get('description', self.widget_vars['steps_data'][idx].get('step_desc', ''))}")
        listbox.insert(idx+1, f"{self.widget_vars['steps_data'][idx+1]['step_id']} - {self.widget_vars['steps_data'][idx+1].get('description', self.widget_vars['steps_data'][idx+1].get('step_desc', ''))}")
        listbox.select_set(idx+1)

    def save_current_quest(self):
        """儲存當前任務"""
        if not self.current_quest_id:
            return

        # 找到任務
        quest_to_update = None
        for quest in self.data_cache['quests']['quests']:
            if quest['quest_id'] == self.current_quest_id:
                quest_to_update = quest
                break

        if not quest_to_update:
            return

        # ✅ 從帶說明的值中提取實際類型
        quest_type_full = self.widget_vars['quest_type'].get()
        quest_type = quest_type_full.split(' - ')[0] if ' - ' in quest_type_full else quest_type_full

        # 更新數據
        quest_to_update['quest_id'] = self.widget_vars['quest_id'].get()
        quest_to_update['quest_name'] = self.widget_vars['quest_name'].get()
        quest_to_update['quest_desc'] = self.widget_vars['quest_desc'].get("1.0", tk.END).strip()
        quest_to_update['quest_type'] = quest_type
        quest_to_update['is_mandatory'] = self.widget_vars['is_mandatory'].get()
        quest_to_update['auto_start'] = self.widget_vars['auto_start'].get()
        quest_to_update['steps'] = self.widget_vars['steps_data']
        quest_to_update['rewards'] = {
            "gold": self.widget_vars['reward_gold'].get(),
            "diamond": self.widget_vars['reward_diamond'].get(),
            "cards": []
        }
        quest_to_update['next_quest'] = self.widget_vars['next_quest'].get()

        # 更新 ID
        self.current_quest_id = quest_to_update['quest_id']

        # 儲存到檔案
        self.save_data_to_file('quests')

        # 更新列表
        self.populate_quests_tab()
        messagebox.showinfo("成功", "任務已儲存！")

    def add_new_quest(self):
        """新增任務"""
        new_id = simpledialog.askstring("新增任務", "請輸入新任務的 ID:", parent=self.root)
        if not new_id:
            return

        # 檢查重複
        for quest in self.data_cache['quests']['quests']:
            if quest['quest_id'] == new_id:
                messagebox.showerror("錯誤", "此 ID 已存在！")
                return

        # 新增
        new_quest = {
            "quest_id": new_id,
            "quest_name": "新任務",
            "quest_desc": "新任務描述",
            "quest_type": "tutorial",
            "is_mandatory": False,
            "auto_start": False,
            "steps": [],
            "rewards": {
                "gold": 0,
                "diamond": 0,
                "cards": []
            }
        }

        self.data_cache['quests']['quests'].append(new_quest)
        self.save_data_to_file('quests')
        self.populate_quests_tab()

    def delete_current_quest(self):
        """刪除當前任務"""
        if not self.quest_listbox.curselection():
            return

        idx = self.quest_listbox.curselection()[0]
        quest_id = self.data_cache['quests']['quests'][idx]['quest_id']

        if not messagebox.askyesno("確認", f"確定要刪除任務 {quest_id} 嗎？"):
            return

        self.data_cache['quests']['quests'].pop(idx)
        self.save_data_to_file('quests')
        self.populate_quests_tab()


# ========== 彈窗編輯器 ==========

class ChoiceEditorDialog(tk.Toplevel):
    """對話選項編輯彈窗"""

    def __init__(self, parent, action_types, choice_data=None):
        super().__init__(parent)
        self.transient(parent)
        self.grab_set()
        self.title("編輯選項")
        self.geometry("500x300")

        self.action_types = action_types
        self.result = None

        # 文字
        ttk.Label(self, text="選項文字:", font=("Arial", 10, "bold")).pack(anchor='w', padx=10, pady=(10, 0))
        self.text_var = tk.StringVar(value=choice_data.get('text', '') if choice_data else '')
        ttk.Entry(self, textvariable=self.text_var).pack(fill='x', padx=10, pady=(0, 10))

        # 動作
        ttk.Label(self, text="動作 (action):", font=("Arial", 10, "bold")).pack(anchor='w', padx=10, pady=(0, 0))
        ttk.Label(self, text="選擇玩家點擊此選項後的行為", foreground="gray").pack(anchor='w', padx=10)

        current_action = choice_data.get('action', 'next') if choice_data else 'next'
        self.action_var = tk.StringVar(value=current_action)

        # ✅ 顯示帶說明的下拉框
        action_combo = ttk.Combobox(self, textvariable=self.action_var,
                                    values=list(self.action_types.values()),
                                    state='readonly',
                                    width=50)
        action_combo.pack(fill='x', padx=10, pady=(0, 10))

        # ✅ 設置當前值（匹配格式）
        for key, value in self.action_types.items():
            if key == current_action:
                action_combo.set(value)
                break

        # 說明
        info_frame = ttk.Frame(self)
        info_frame.pack(fill='both', expand=True, padx=10, pady=10)

        ttk.Label(info_frame, text="ℹ️ Action 說明:", font=("Arial", 9, "bold")).pack(anchor='w')

        info_text = tk.Text(info_frame, height=6, wrap=tk.WORD, bg="#f0f0f0")
        info_text.pack(fill='both', expand=True, pady=(5, 0))
        info_text.insert(tk.END, "\n".join([f"• {desc}" for desc in self.action_types.values()]))
        info_text.config(state=tk.DISABLED)

        # 按鈕
        btn_frame = ttk.Frame(self)
        btn_frame.pack(fill='x', padx=10, pady=(0, 10))
        ttk.Button(btn_frame, text="取消", command=self.destroy).pack(side=tk.RIGHT, padx=(5, 0))
        ttk.Button(btn_frame, text="確定", command=self.save).pack(side=tk.RIGHT)

    def save(self):
        """儲存"""
        # ✅ 從帶說明的值中提取實際 action
        action_full = self.action_var.get()
        action = action_full.split(' - ')[0] if ' - ' in action_full else action_full

        self.result = {
            "text": self.text_var.get(),
            "action": action
        }
        self.destroy()


class StepEditorDialog(tk.Toplevel):
    """任務步驟編輯彈窗"""

    def __init__(self, parent, condition_types, step_data=None):
        super().__init__(parent)
        self.transient(parent)
        self.grab_set()
        self.title("編輯步驟")
        self.geometry("600x550")

        self.condition_types = condition_types
        self.result = None

        # 建立捲動區域
        canvas = tk.Canvas(self)
        scrollbar = ttk.Scrollbar(self, orient="vertical", command=canvas.yview)
        form_frame = ttk.Frame(canvas)

        form_frame.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=form_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=10, pady=10)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # Step ID
        ttk.Label(form_frame, text="步驟 ID:", font=("Arial", 10, "bold")).pack(anchor='w', pady=(5, 0))
        self.step_id_var = tk.StringVar(value=step_data.get('step_id', '') if step_data else '')
        ttk.Entry(form_frame, textvariable=self.step_id_var).pack(fill='x', pady=(0, 10))

        # Step 描述
        ttk.Label(form_frame, text="步驟描述:", font=("Arial", 10, "bold")).pack(anchor='w', pady=(0, 0))
        self.step_desc_var = tk.StringVar(value=step_data.get('description', step_data.get('step_desc', '')) if step_data else '')
        ttk.Entry(form_frame, textvariable=self.step_desc_var).pack(fill='x', pady=(0, 10))

        # Dialog ID
        ttk.Label(form_frame, text="對話 ID (可選):", font=("Arial", 10, "bold")).pack(anchor='w', pady=(0, 0))
        self.dialog_id_var = tk.StringVar(value=step_data.get('dialog_id', '') if step_data else '')
        ttk.Entry(form_frame, textvariable=self.dialog_id_var).pack(fill='x', pady=(0, 10))

        ttk.Separator(form_frame, orient='horizontal').pack(fill='x', pady=10)

        # Condition Type
        ttk.Label(form_frame, text="條件類型:", font=("Arial", 10, "bold")).pack(anchor='w', pady=(0, 0))
        ttk.Label(form_frame, text="選擇此步驟完成的條件", foreground="gray").pack(anchor='w')

        conditions = step_data.get('condition', step_data.get('conditions', {})) if step_data else {}
        current_condition = conditions.get('type', 'dialog_completed')
        self.condition_type_var = tk.StringVar(value=current_condition)

        # ✅ 顯示帶說明的下拉框
        condition_combo = ttk.Combobox(form_frame, textvariable=self.condition_type_var,
                                      values=list(self.condition_types.values()),
                                      state='readonly',
                                      width=50)
        condition_combo.pack(fill='x', pady=(0, 10))

        # ✅ 設置當前值
        for key, value in self.condition_types.items():
            if key == current_condition:
                condition_combo.set(value)
                break

        # 說明
        info_frame = ttk.LabelFrame(form_frame, text="ℹ️ Condition 類型說明")
        info_frame.pack(fill='both', expand=True, pady=(0, 10))

        info_text = tk.Text(info_frame, height=8, wrap=tk.WORD, bg="#f0f0f0")
        info_text.pack(fill='both', expand=True, padx=5, pady=5)
        info_text.insert(tk.END, "\n".join([f"• {desc}" for desc in self.condition_types.values()]))
        info_text.config(state=tk.DISABLED)

        # Condition JSON
        ttk.Label(form_frame, text="條件 JSON (進階):", font=("Arial", 10, "bold")).pack(anchor='w', pady=(0, 0))
        ttk.Label(form_frame, text="可以在此直接編輯完整的條件 JSON", foreground="gray").pack(anchor='w')
        self.condition_json = tk.Text(form_frame, height=6, wrap=tk.WORD)
        self.condition_json.insert(tk.END, json.dumps(conditions, ensure_ascii=False, indent=2))
        self.condition_json.pack(fill='x', pady=(0, 20))

        # 按鈕
        btn_frame = ttk.Frame(form_frame)
        btn_frame.pack(fill='x')
        ttk.Button(btn_frame, text="取消", command=self.destroy).pack(side=tk.RIGHT, padx=(5, 0))
        ttk.Button(btn_frame, text="確定", command=self.save).pack(side=tk.RIGHT)

    def save(self):
        """儲存"""
        # ✅ 從帶說明的值中提取實際條件類型
        condition_full = self.condition_type_var.get()
        condition_type = condition_full.split(' - ')[0] if ' - ' in condition_full else condition_full

        try:
            conditions = json.loads(self.condition_json.get("1.0", tk.END))
            # 更新 type 為選擇的值
            conditions['type'] = condition_type
        except:
            conditions = {"type": condition_type}

        self.result = {
            "step_id": self.step_id_var.get(),
            "description": self.step_desc_var.get(),
            "condition": conditions  # ✅ 使用 "condition" 而不是 "conditions"
        }

        # 如果有 dialog_id，添加進去
        if self.dialog_id_var.get():
            self.result["dialog_id"] = self.dialog_id_var.get()

        self.destroy()


# ========== 主程式 ==========

if __name__ == "__main__":
    root = tk.Tk()
    app = DialogTaskEditor(root)
    root.mainloop()