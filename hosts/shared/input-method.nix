{ ... }:

# 輸入法的 home 端單一真相＝rime 使用者設定（schema／日後詞庫）。
# 框架與引擎（fcitx5 + addons）在系統層 hosts/shared/locale.nix，才壓得過 GNOME 的
# ibus 預設；這裡只放屬於使用者資料、且可免 sudo 迭代的部分。
#
# 分層一句話：locale.nix 選「用哪套 IM」（罕改、要 sudo）；本檔調「rime 怎麼打」（常改、免 sudo）。
{
  # rime 注音：把 bopomofo 掛進「啟用 schema 清單」（rime 預設只給拼音，不設就沒注音）。
  # 只宣告 *.custom.yaml（rime 唯讀它）；build/ 與使用者詞庫仍由 rime deploy 自行寫入，
  # 故不整包接管此目錄，免與 rime 產物打架。改完須「右鍵托盤 → 部署」才生效。
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      schema_list:
        - schema: bopomofo
  '';
}
