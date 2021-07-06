#-------------------------------
# octopus プロジェクトを生成する
#-------------------------------

function octopus_init() {
  # 必須コマンドがなければインストールを促す
  if [[ ! $(command -v docker) ]]; then
    echo 'octopus コマンドを実行するには、 docker が必要です。'
    echo '下記コマンドを実行し、 docker をインストールしてください。\n'
    echo 'brew install --cask docker\n'
    exit 1
  fi

  if [[ ! $(command -v mkcert) ]]; then
    echo 'octopus コマンドを実行するには、 mkcert が必要です。'
    echo '下記コマンドを実行し、 mkcert をインストールしてください。\n'
    echo 'brew install mkcert'
    echo 'mkcert -install\n'
    exit 1
  fi

  if [[ ! $(command -v wp) ]]; then
    echo 'octopus コマンドを実行するには、 WP-CLI が必要です。'
    echo '下記コマンドを実行し、 WP-CLI をインストールしてください。\n'
    echo 'curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar'
    echo 'php wp-cli.phar --info'
    echo 'chmod +x wp-cli.phar'
    echo 'sudo mv wp-cli.phar /usr/local/bin/wp\n'
    exit 1
  fi

  # GitHubホスト名の確認＆登録
  if [ -z $(git config --global ssh.host) ]; then
    echo -n 'WEB DESIGN 84 GitHub SSH Host > '
    read github_ssh_host
    if [ -z "$github_ssh_host" ]; then
      echo 'GitHubのSSHホスト名（~/.ssh/config に記述）を入力してください。'
      exit 1
    elif [[ ! $(grep $github_ssh_host ~/.ssh/config) ]]; then
      echo '~/.ssh/config にホストが登録されていません。'
      exit 1
    fi
    git config --global ssh.host $github_ssh_host
  fi

  # プロジェクト名
  echo -n 'Project Name > '
  read project_name
  if [ -z "$project_name" ]; then
    echo 'プロジェクト名を入力してください。'
    exit 1
  elif [ -d $HOME/projects/$project_name ]; then
    echo '既にプロジェクトが存在します。他の名前をお試しください。'
    exit 1
  fi

  # サイト名
  echo -n 'Site Title > '
  read site_title
  if [ -z "$site_title" ]; then
    echo 'サイト名を入力してください。'
    exit 1
  fi

  # ドメイン名
  echo -n 'Domain > '
  read domain
  if [ -z "$domain" ]; then
    echo 'ドメイン名を入力してください。'
    exit 1
  elif grep -q "$domain" /etc/hosts; then
    echo "'$domain' はすでに存在します。"
    echo '/etc/hosts からドメインを削除するか、他のドメインを入力してください。'
    exit 1
  fi

  # ホストIP
  for i in {1..20}; do
    if ! grep -q "127.0.0.$i" /etc/hosts; then
      local ip="127.0.0.$i"
      break
    fi
  done
  if [ -z "$ip" ]; then
    echo 'ローカルループバックアドレスに空きがありません。'
    echo '新たに確保するか、不使用のプロジェクトを整理してください。'
    exit 1
  fi

  # 確認後、プロジェクトの作成
  echo '下記の内容でプロジェクトを作成します。よろしいですか（y/n）'
  echo '--------------------------'
  echo "プロジェクト名：$project_name"
  echo "サイト名：$site_title"
  echo "ドメイン：$domain"
  echo "ホストIPアドレス：$ip"
  echo '--------------------------'
  if ! read -sq; then
    echo 'Octopusプロジェクトの作成をキャンセルしました。'
    exit
  fi

  # ~/projects が存在しない場合、ホームディレクトリへ作成する
  if [ ! -d $HOME/projects ]; then
    mkdir $HOME/projects
  fi

  # ~/projects/$project_name/dev にOctopusをインストール
  cd $HOME/projects
  mkdir $project_name && cd $project_name
  git clone $(git config --global ssh.host):web-design-84/Octopus.git dev
  if [ ! -d $HOME/projects/$project_name/dev ]; then
    echo 'クローンに失敗しました。'
    echo 'GitHubのホスト名を見直してください。'
    exit 1
  fi

  # 初期設定
  cd dev && rm -rf .git && mkdir {sql/db_data,mailhog}
  yarn

  # .env の書き換え
  sed -i '' -e "s/^PRODUCTION_NAME=.*$/PRODUCTION_NAME=$project_name/" -e "s/^SITE_TITLE=.*$/SITE_TITLE='$site_title'/" -e "s/^DOMAIN=.*$/DOMAIN='$domain'/" -e "s/^HOST_IP=.*$/HOST_IP=$ip/" .env

  # 証明書の作成
  mkdir certs
  mkcert -cert-file ./certs/cert.pem -key-file ./certs/cert.key $domain

  # WordPress日本語版コアファイルのダウンロード
  wp core download --locale=ja

  # コンテナの立ち上げ
  docker compose -p $project_name up -d --build

  # 立ち上がりを待つ
  echo 'コンテナ起動の安定を待っています。30秒お待ちください🐙'
  for i in {1..10}; do
    # 進捗10%あたり "###" を出力
    local bar="$(yes '###' | head -n $i | tr -d '\n')"
    local spaces=''
    if [[ $i < 10 ]]; then
      local spaces=$(printf ".%0.s" {1..$((30 - ${#bar}))})
    fi
    printf "\r[%3d/100] %s%s" $((i * 10)) $bar $spaces
    sleep 3
  done
  printf '\n'

  # WP-CLIによるWordPressセットアップ
  docker exec "${project_name}_dev_wp" /bin/zsh setup-wp.sh

  # /etc/hosts にホストを追加
  echo 'honoka' | sudo -S -p '' zsh -c "echo \"# $site_title\n$ip $domain\n\" >> /etc/hosts"

  # 完了
  echo "~/projects/$project_name/dev へOctopusプロジェクトを作成しました！"
  exit
}
