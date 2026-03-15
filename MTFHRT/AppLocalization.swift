import Foundation

enum AppLocalization {
    static var currentLanguage: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"
    }

    static func text(_ key: String, lang: String) -> String {
        let table: [String: (zhHans: String, zhHant: String, en: String)] = [
            "tab.hrt": ("HRT", "HRT", "HRT"),
            "tab.labs": ("化验", "化驗", "Labs"),
            "tab.brief": ("简报", "簡報", "Brief"),
            "tab.settings": ("设置", "設定", "Settings"),
            "guide.title": ("功能引导", "功能引導", "Feature Guide"),
            "guide.skip": ("跳过", "略過", "Skip"),
            "guide.next": ("下一步", "下一步", "Next"),
            "guide.finish": ("完成", "完成", "Finish"),
            "guide.step_counter": ("步骤 %@/%@", "步驟 %@/%@", "Step %@/%@"),
            "guide.step1.title": ("设置当前用药计划", "設定目前用藥計劃", "Set Current Medication Plan"),
            "guide.step1.desc": ("点这里：HRT 页右上角按钮，填写当前雌二醇/抗雄频率与剂量。", "點這裡：HRT 頁右上角按鈕，填寫目前雌二醇/抗雄頻率與劑量。", "Tap here: top-right button on HRT tab to set estradiol/anti-androgen frequency and dose."),
            "guide.step2.title": ("每日打卡", "每日打卡", "Daily Check-in"),
            "guide.step2.desc": ("点这里：HRT 页中央圆形按钮，每天打卡一次并记录时间。", "點這裡：HRT 頁中央圓形按鈕，每天打卡一次並記錄時間。", "Tap here: large circular button on HRT tab once per day to record check-in time."),
            "guide.step3.title": ("上传化验报告", "上傳化驗報告", "Upload Lab Report"),
            "guide.step3.desc": ("点这里：化验页右上角 +，先上传图片再 OCR 识别指标。", "點這裡：化驗頁右上角 +，先上傳圖片再 OCR 識別指標。", "Tap here: + on Labs tab, upload image first, then OCR fills values."),
            "guide.step4.title": ("查看报告解读", "查看報告解讀", "View Interpretation"),
            "guide.step4.desc": ("保存报告后，进入报告详情可查看双低/双高/正常与调整建议。", "儲存報告後，進入報告詳情可查看雙低/雙高/正常與調整建議。", "After saving, open report details to see interpretation and adjustment suggestion."),
            "guide.step5.title": ("向医生展示简报", "向醫師展示簡報", "Share Brief with Doctor"),
            "guide.step5.desc": ("点这里：简报页可直接展示当前用药与近期化验，便于沟通。", "點這裡：簡報頁可直接展示目前用藥與近期化驗，便於溝通。", "Tap here: Brief tab summarizes current plan and recent labs for clinician discussion."),

            "settings.title": ("设置", "設定", "Settings"),
            "settings.profile": ("个人信息", "個人資訊", "Profile"),
            "settings.preferences": ("偏好设置", "偏好設定", "Preferences"),
            "settings.language": ("语言", "語言", "Language"),
            "settings.onboarding": ("首次引导", "首次引導", "Onboarding"),
            "settings.replay_onboarding": ("重新查看引导", "重新查看引導", "Replay Onboarding"),
            "settings.avatar": ("设置头像", "設定頭像", "Set Avatar"),
            "settings.name": ("名字", "名字", "Name"),
            "settings.birth_date": ("出生日期", "出生日期", "Birth Date"),
            "settings.age": ("年龄", "年齡", "Age"),
            "settings.hrt_start": ("HRT 开始日期", "HRT 開始日期", "HRT Start Date"),
            "settings.daily_reminder": ("每日 HRT 服药提醒", "每日 HRT 服藥提醒", "Daily HRT Reminder"),
            "settings.enable_daily": ("开启每日提醒", "開啟每日提醒", "Enable Daily Reminder"),
            "settings.reminder_time": ("提醒时间", "提醒時間", "Reminder Time"),
            "settings.lab_reminder": ("激素检查提醒", "激素檢查提醒", "Lab Check Reminder"),
            "settings.last_lab": ("上次检查日期", "上次檢查日期", "Last Check Date"),
            "settings.lab_interval": ("检查间隔：每 %@ 周", "檢查間隔：每 %@ 週", "Interval: every %@ weeks"),
            "settings.next_lab": ("下次建议检查", "下次建議檢查", "Next Suggested Check"),
            "settings.schedule_lab": ("安排检查提醒通知", "安排檢查提醒通知", "Schedule Lab Reminder"),
            "settings.reminder.off": ("每日提醒已关闭。", "每日提醒已關閉。", "Daily reminder is turned off."),
            "settings.notification_denied": ("通知权限未开启，请在系统设置中允许通知。", "通知權限未開啟，請在系統設定中允許通知。", "Notifications are disabled. Please allow notifications in Settings."),
            "settings.reminder.set_to": ("每日提醒已设置为 %@。", "每日提醒已設定為 %@。", "Daily reminder set to %@."),
            "settings.reminder.failed": ("提醒设置失败：%@", "提醒設定失敗：%@", "Failed to set reminder: %@"),
            "settings.daily.title": ("HRT 服药提醒", "HRT 服藥提醒", "HRT Medication Reminder"),
            "settings.daily.body": ("记得按计划完成今天的 HRT 打卡与服药。", "記得按計劃完成今天的 HRT 打卡與服藥。", "Remember to complete today's HRT check-in and medication."),
            "settings.lab.title": ("激素检查提醒", "激素檢查提醒", "Lab Check Reminder"),
            "settings.lab.body": ("到建议复查时间了，记得安排激素检查。", "到建議複查時間了，記得安排激素檢查。", "It's time for your suggested follow-up lab check."),
            "settings.lab.scheduled": ("已安排：%@。", "已安排：%@。", "Scheduled: %@."),
            "settings.set_failed": ("设置失败：%@", "設定失敗：%@", "Failed to set: %@"),

            "hrt.title": ("HRT 打卡", "HRT 打卡", "HRT Check-in"),
            "hrt.current_plan": ("当前用药计划", "當前用藥計劃", "Current Plan"),
            "hrt.no_plan": ("暂无计划", "暫無計劃", "No current plan"),
            "hrt.recent_checkins": ("近期打卡", "近期打卡", "Recent Check-ins"),
            "hrt.set_plan": ("设置计划", "設定計劃", "Set Plan"),
            "hrt.edit_plan": ("编辑计划", "編輯計劃", "Edit Plan"),
            "hrt.taken": ("已服药", "已服藥", "Taken"),
            "hrt.skipped": ("未服药", "未服藥", "Skipped"),
            "hrt.updated": ("更新于", "更新於", "Updated"),
            "hrt.check.in_days": ("%@ 天后应该激素检查", "%@ 天後應該激素檢查", "Lab check due in %@ days"),
            "hrt.check.today": ("今天应该激素检查", "今天應該激素檢查", "Lab check due today"),
            "hrt.check.overdue": ("已超期 %@ 天，请尽快激素检查", "已超期 %@ 天，請盡快激素檢查", "Overdue by %@ days, please check soon"),
            "hrt.day_count": ("已经 HRT %@ 天", "已經 HRT %@ 天", "HRT Day %@"),
            "hrt.day_count_start": ("开始 HRT 打卡", "開始 HRT 打卡", "Start HRT Check-ins"),
            "hrt.checked_today": ("今日已打卡", "今日已打卡", "Checked in today"),
            "hrt.not_checked_today": ("今日未打卡", "今日未打卡", "Not checked in today"),
            "hrt.prompt_set_plan": ("请先设置用药计划", "請先設定用藥計劃", "Set your plan first"),
            "hrt.prompt_tap_checkin": ("点击按钮完成今日打卡", "點擊按鈕完成今日打卡", "Tap to complete today's check-in"),
            "hrt.plan.estrogen": ("雌二醇", "雌二醇", "Estradiol"),
            "hrt.plan.anti_androgen": ("抗雄", "抗雄", "Anti-androgen"),
            "hrt.plan.updated": ("更新于", "更新於", "Updated"),
            "hrt.birthday_message": ("今天长大了一岁，新的一年要好好爱自己。", "今天長大了一歲，新的一年要好好愛自己。", "You grew one year today. Love yourself in this new year."),
            "hrt.done_today": ("今天也完成了。", "今天也完成了。", "Done for today."),
            "common.plus_one": ("+1", "+1", "+1"),

            "plan.section.estrogen": ("雌二醇", "雌二醇", "Estrogen"),
            "plan.section.aa": ("抗雄", "抗雄", "Anti-androgen"),
            "plan.route": ("用药方式", "用藥方式", "Route"),
            "plan.freq": ("频率：每 %@ %@ 一次", "頻率：每 %@ %@ 一次", "Frequency: every %@ %@"),
            "plan.freq_unit": ("频率单位", "頻率單位", "Frequency Unit"),
            "plan.medication": ("药品", "藥品", "Medication"),
            "plan.custom": ("自定义", "自訂", "Custom"),
            "plan.medication_name": ("药品名称", "藥品名稱", "Medication Name"),
            "plan.dose_optional": ("剂量 (mg，可选)", "劑量 (mg，可選)", "Dose (mg, optional)"),
            "plan.note_optional": ("备注（可选）", "備註（可選）", "Note (optional)"),
            "plan.title": ("当前计划", "當前計劃", "Current Plan"),
            "plan.cancel": ("取消", "取消", "Cancel"),
            "plan.save": ("保存", "儲存", "Save"),
            "common.day": ("天", "天", "day(s)"),
            "common.week": ("周", "週", "week(s)"),
            "route.oral": ("口服", "口服", "Oral"),
            "route.gel": ("凝胶", "凝膠", "Gel"),
            "route.injection": ("针剂", "針劑", "Injection"),

            "med.custom": ("自定义", "自訂", "Custom"),
            "med.estrogen.progynova": ("补佳乐", "補佳樂", "Progynova"),
            "med.estrogen.nokunfu": ("诺坤复", "諾坤復", "Nokunfu"),
            "med.estrogen.estrogel": ("爱斯妥凝胶", "愛斯妥凝膠", "Estrogel"),
            "med.estrogen.estradiol_gel": ("雌二醇凝胶", "雌二醇凝膠", "Estradiol Gel"),
            "med.estrogen.estradiol_valerate_inj": ("戊酸雌二醇针剂", "戊酸雌二醇針劑", "Estradiol Valerate Injection"),
            "med.estrogen.estradiol_benzoate_inj": ("苯甲酸雌二醇针剂", "苯甲酸雌二醇針劑", "Estradiol Benzoate Injection"),
            "med.aa.spironolactone": ("螺内酯", "螺內酯", "Spironolactone"),
            "med.aa.cyproterone": ("醋酸环丙孕酮", "醋酸環丙孕酮", "Cyproterone Acetate"),
            "med.aa.bicalutamide": ("比卡鲁胺", "比卡魯胺", "Bicalutamide"),

            "labs.title": ("检查与化验", "檢查與化驗", "Labs"),
            "labs.section.reports": ("化验报告", "化驗報告", "Lab Reports"),
            "labs.empty.title": ("还没有化验报告", "還沒有化驗報告", "No lab reports yet"),
            "labs.empty.desc": ("点击右上角 + 添加一次完整检查。", "點擊右上角 + 添加一次完整檢查。", "Tap + to add a full lab check."),
            "labs.add.title": ("新增化验报告", "新增化驗報告", "Add Lab Report"),
            "labs.add.cancel": ("取消", "取消", "Cancel"),
            "labs.add.save": ("保存报告", "儲存報告", "Save Report"),
            "labs.add.section.info": ("报告信息", "報告資訊", "Report Info"),
            "labs.add.section.ocr": ("OCR", "OCR", "OCR"),
            "labs.add.section.preview": ("报告解读（预览）", "報告解讀（預覽）", "Interpretation (Preview)"),
            "labs.add.result": ("结果", "結果", "Result"),
            "labs.add.suggestion": ("建议", "建議", "Suggestion"),
            "labs.add.need_e2_t": ("先输入 E2 和 T 才能解读。", "先輸入 E2 和 T 才能解讀。", "Enter E2 and T to preview interpretation."),
            "labs.add.disclaimer": ("此解读仅用于整理讨论，不替代医生诊疗建议。", "此解讀僅用於整理討論，不替代醫師診療建議。", "This interpretation is for discussion only and does not replace medical advice."),
            "labs.add.upload_ocr": ("上传报告图片并识别", "上傳報告圖片並識別", "Upload report image and run OCR"),
            "labs.ocr.running": ("正在识别图片...", "正在識別圖片...", "Recognizing image..."),
            "labs.ocr.read_failed": ("无法读取图片数据。", "無法讀取圖片資料。", "Unable to read image data."),
            "labs.ocr.date_only": ("识别完成，已自动更新检查日期。未匹配到可填充项目。", "識別完成，已自動更新檢查日期。未匹配到可填充項目。", "OCR done. Date updated, but no fields were matched."),
            "labs.ocr.none": ("识别完成，但未匹配到可填充项目。请手动输入或换更清晰图片。", "識別完成，但未匹配到可填充項目。請手動輸入或更換更清晰圖片。", "OCR done, but no fields were matched. Please enter manually or use a clearer image."),
            "labs.ocr.filled_and_date": ("识别完成，已自动填充 %@ 个项目并更新检查日期。请确认后保存。", "識別完成，已自動填充 %@ 個項目並更新檢查日期。請確認後儲存。", "OCR done. Filled %@ fields and updated date. Please review and save."),
            "labs.ocr.filled": ("识别完成，已自动填充 %@ 个项目。请确认后保存。", "識別完成，已自動填充 %@ 個項目。請確認後儲存。", "OCR done. Filled %@ fields. Please review and save."),
            "labs.ocr.failed": ("OCR 失败：%@", "OCR 失敗：%@", "OCR failed: %@"),
            "labs.add.date": ("检查日期", "檢查日期", "Check Date"),
            "labs.add.e2": ("雌二醇 E2", "雌二醇 E2", "Estradiol E2"),
            "labs.add.e2_unit": ("E2 单位", "E2 單位", "E2 Unit"),
            "labs.add.t": ("总睾酮 T", "總睾酮 T", "Total Testosterone T"),
            "labs.add.t_unit": ("T 单位", "T 單位", "T Unit"),
            "labs.add.prl": ("PRL（可选）", "PRL（可選）", "PRL (optional)"),
            "labs.add.prl_unit": ("PRL 单位", "PRL 單位", "PRL Unit"),
            "labs.add.shbg": ("SHBG (nmol/L，可选)", "SHBG (nmol/L，可選)", "SHBG (nmol/L, optional)"),
            "labs.add.alt": ("ALT (U/L，可选)", "ALT (U/L，可選)", "ALT (U/L, optional)"),
            "labs.add.ast": ("AST (U/L，可选)", "AST (U/L，可選)", "AST (U/L, optional)"),
            "labs.add.note": ("备注（可选）", "備註（可選）", "Note (optional)"),
            "labs.detail.results": ("结果", "結果", "Results"),
            "labs.detail.interpretation": ("解读", "解讀", "Interpretation"),
            "labs.detail.note": ("备注", "備註", "Note"),
            "labs.detail.image": ("报告图片", "報告圖片", "Report Image"),
            "labs.detail.title": ("报告详情", "報告詳情", "Report Detail"),
            "labs.detail.delete_confirm_title": ("删除这份报告？", "刪除這份報告？", "Delete this report?"),
            "labs.detail.delete": ("删除", "刪除", "Delete"),
            "labs.detail.cannot_undo": ("删除后不可恢复。", "刪除後不可恢復。", "This action cannot be undone."),

            "interpretation.dualLow": ("双低", "雙低", "Both Low"),
            "interpretation.dualHigh": ("双高", "雙高", "Both High"),
            "interpretation.normal": ("正常", "正常", "Normal"),
            "interpretation.estradiolLow": ("雌二醇低", "雌二醇低", "Low Estradiol"),
            "interpretation.estradiolHigh": ("雌二醇高", "雌二醇高", "High Estradiol"),
            "interpretation.testosteroneLow": ("睾酮低", "睪酮低", "Low Testosterone"),
            "interpretation.testosteroneHigh": ("睾酮高", "睪酮高", "High Testosterone"),
            "suggestion.adjustEstradiol": ("建议调整：雌二醇", "建議調整：雌二醇", "Suggested adjustment: Estradiol"),
            "suggestion.adjustAntiAndrogen": ("建议调整：抗雄", "建議調整：抗雄", "Suggested adjustment: Anti-androgen"),
            "suggestion.noAdjustment": ("建议调整：无需调整", "建議調整：無需調整", "Suggested adjustment: No change"),

            "report.title": ("简报", "簡報", "Brief"),
            "report.section.clinician": ("临床简报", "臨床簡報", "Clinician Brief"),
            "report.generated": ("生成时间", "生成時間", "Generated"),
            "report.disclaimer": ("该简报仅用于与医生沟通，不用于自我诊断。", "該簡報僅用於與醫師溝通，不用於自我診斷。", "Use this summary for clinician discussion, not for self-diagnosis."),
            "report.section.current_pattern": ("当前 HRT 方案", "當前 HRT 方案", "Current HRT Pattern"),
            "report.section.adherence": ("打卡依从性（7天）", "打卡依從性（7天）", "Check-in adherence (7 days)"),
            "report.section.recent_results": ("近期结果", "近期結果", "Recent results"),
            "report.section.rule_suggestion": ("规则建议", "規則建議", "Rule-based suggestion"),
            "report.section.resources": ("医疗资源（MtF.wiki）", "醫療資源（MtF.wiki）", "Resources (MtF.wiki)"),
            "report.open_resources": ("寻找HRT医疗资源", "尋找HRT醫療資源", "Find HRT Resources"),
            "report.source_credit": ("内容来源感谢：mtf.wiki", "內容來源感謝：mtf.wiki", "Content source: mtf.wiki"),
            "report.no_plan": ("暂无计划", "暫無計劃", "No plan set."),
            "report.no_checkins": ("暂无打卡记录。", "暫無打卡紀錄。", "No check-ins yet."),
            "report.no_data": ("暂无数据。", "暫無資料。", "No data."),
            "report.no_trigger": ("暂无可触发建议。", "暫無可觸發建議。", "No trigger-based suggestion."),
            "report.taken_days": ("%@/%@ 天已标记为服药", "%@/%@ 天已標記為服藥", "%@/%@ days marked as taken"),

            "wiki.title": ("医疗资源", "醫療資源", "Resources"),
            "wiki.section.info": ("说明", "說明", "Info"),
            "wiki.info.desc": ("以下内容来自 App 内置 Markdown 文件（离线可读）。", "以下內容來自 App 內建 Markdown 檔案（離線可讀）。", "Content below comes from bundled Markdown files (offline)."),
            "wiki.info.source": ("内容来源感谢：mtf.wiki", "內容來源感謝：mtf.wiki", "Content source: mtf.wiki"),
            "wiki.empty.title": ("未找到离线内容", "未找到離線內容", "No offline content found"),
            "wiki.empty.desc": ("请确认 MTFWikiOfflineMD 下的 .md 文件已加入 App target。", "請確認 MTFWikiOfflineMD 下的 .md 檔案已加入 App target。", "Make sure .md files in MTFWikiOfflineMD are included in the app target."),
            "wiki.section.cn": ("中国大陆地区医疗资源", "中國大陸地區醫療資源", "Mainland China Resources"),
            "wiki.source.short": ("来源感谢：mtf.wiki", "來源感謝：mtf.wiki", "Source: mtf.wiki"),
            "wiki.loading": ("加载中...", "載入中...", "Loading...")
        ]

        let row = table[key]
        switch lang {
        case "zh-Hant":
            return row?.zhHant ?? key
        case "en":
            return row?.en ?? key
        default:
            return row?.zhHans ?? key
        }
    }

    static func text(_ key: String) -> String {
        text(key, lang: currentLanguage)
    }

    static func format(_ key: String, _ arg: CustomStringConvertible, lang: String) -> String {
        String(format: text(key, lang: lang), "\(arg)")
    }

    static func format(_ key: String, _ arg1: CustomStringConvertible, _ arg2: CustomStringConvertible, lang: String) -> String {
        String(format: text(key, lang: lang), "\(arg1)", "\(arg2)")
    }

    static func format(_ key: String, _ arg: CustomStringConvertible) -> String {
        format(key, arg, lang: currentLanguage)
    }

    static func format(_ key: String, _ arg1: CustomStringConvertible, _ arg2: CustomStringConvertible) -> String {
        format(key, arg1, arg2, lang: currentLanguage)
    }

    static func medicationCanonicalID(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases: [String: String] = [
            "progynova": "progynova",
            "补佳乐": "progynova",
            "補佳樂": "progynova",

            "nokunfu": "nokunfu",
            "诺坤复": "nokunfu",
            "諾坤復": "nokunfu",

            "estrogel": "estrogel",
            "爱斯妥凝胶": "estrogel",
            "愛斯妥凝膠": "estrogel",

            "estradiol_gel": "estradiol_gel",
            "雌二醇凝胶": "estradiol_gel",
            "雌二醇凝膠": "estradiol_gel",

            "estradiol_valerate_inj": "estradiol_valerate_inj",
            "戊酸雌二醇针剂": "estradiol_valerate_inj",
            "戊酸雌二醇針劑": "estradiol_valerate_inj",

            "estradiol_benzoate_inj": "estradiol_benzoate_inj",
            "苯甲酸雌二醇针剂": "estradiol_benzoate_inj",
            "苯甲酸雌二醇針劑": "estradiol_benzoate_inj",

            "spironolactone": "spironolactone",
            "螺内酯": "spironolactone",
            "螺內酯": "spironolactone",

            "cyproterone": "cyproterone",
            "醋酸环丙孕酮": "cyproterone",
            "醋酸環丙孕酮": "cyproterone",

            "bicalutamide": "bicalutamide",
            "比卡鲁胺": "bicalutamide",
            "比卡魯胺": "bicalutamide",

            "custom": "custom",
            "自定义": "custom",
            "自訂": "custom"
        ]
        return aliases[normalized] ?? value
    }

    static func medicationDisplayName(_ value: String, lang: String) -> String {
        switch medicationCanonicalID(value) {
        case "progynova": return text("med.estrogen.progynova", lang: lang)
        case "nokunfu": return text("med.estrogen.nokunfu", lang: lang)
        case "estrogel": return text("med.estrogen.estrogel", lang: lang)
        case "estradiol_gel": return text("med.estrogen.estradiol_gel", lang: lang)
        case "estradiol_valerate_inj": return text("med.estrogen.estradiol_valerate_inj", lang: lang)
        case "estradiol_benzoate_inj": return text("med.estrogen.estradiol_benzoate_inj", lang: lang)
        case "spironolactone": return text("med.aa.spironolactone", lang: lang)
        case "cyproterone": return text("med.aa.cyproterone", lang: lang)
        case "bicalutamide": return text("med.aa.bicalutamide", lang: lang)
        case "custom": return text("med.custom", lang: lang)
        default: return value
        }
    }
}
