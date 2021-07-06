#-------------------------------
# octopus コマンドのヘルプを表示する
#-------------------------------

function octopus_help() {
  echo '
  ■ Sub commands
  ━━━━━━━━━━━━━━━━
  init      Octopusプロジェクトの作成
  destroy   Octopusプロジェクトの破棄

  ■ Options
  ━━━━━━━━━━━━━━━━
  -v        バージョン
  --help    ヘルプ
  '
  exit
}
