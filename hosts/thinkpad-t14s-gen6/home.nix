{ inputs, pkgs, lib, ... }:

# thinkpad-only 疊加層（疊在 hosts/shared/home.nix 之上）
# 目前只放 codebase-memory-mcp：Claude Code 的程式碼結構索引/查詢加速器。
# 刻意不進 shared，x300m（server）不需要這顆開發工具。

let
  cbm = inputs.codebase-memory-mcp.packages.${pkgs.system}.default;

  # 與 shared/home.nix 的 puppeteerMcpConfig 同模式，註冊成 stdio MCP server
  cbmMcpConfig = builtins.toJSON {
    type = "stdio";
    command = "${cbm}/bin/codebase-memory-mcp";
    args = [ ];
  };
in
{
  # 筆電螢幕近看，把 shared 的 12 調大一點（x300m 接電視則是 18，見 flake.nix）
  # mkForce 才能取代 shared 的定義，否則兩個 font-size 並存、ghostty 取最後一行＝12 失效
  programs.ghostty.settings.font-size = lib.mkForce 14;

  home.packages = [ cbm ];

  # 把 codebase-memory-mcp 寫進 ~/.claude.json（沿用 shared 的 claudeCodeMcp 慣例）
  home.activation.codebaseMemoryMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    CLAUDE_JSON="$HOME/.claude.json"
    if [ ! -f "$CLAUDE_JSON" ]; then
      echo '{}' > "$CLAUDE_JSON"
    fi
    ${pkgs.jq}/bin/jq --argjson p '${cbmMcpConfig}' \
      '.mcpServers."codebase-memory-mcp" = $p' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
      && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
  '';
}
