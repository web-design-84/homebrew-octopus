#-------------------------------
# octopus プロジェクトを削除する
#-------------------------------

function octopus_destroy() {
  echo -n 'Project Name > '
  read project_name
  if [ -z "$project_name" ]; then
    echo 'プロジェクト名を入力してください。'
    exit 1
  elif [ ! -d $HOME/projects/$project_name ]; then
    echo 'プロジェクトが存在しません。'
    exit 1
  fi

  echo "$HOME/projects/$project_name 以下のファイルを全て削除します。本当によろしいですか？（y/n）"
  if ! read -sq; then
    echo 'プロジェクトの破棄をキャンセルしました。'
    exit
  fi

  # Dockerコンテナの削除
  if [[ $(docker compose ls | awk 'NR>1{print $1}' | grep $project_name) ]]; then
    cd $HOME/projects/$project_name/dev
    docker compose -p $project_name down
  fi

  # Dockerイメージの削除
  if [[ $(docker images | awk 'NR>1{print $1}' | grep ${project_name}_wordpress) ]]; then
    docker rmi -f ${project_name}_wordpress
  fi

  # /etc/hosts から割り当てIPを削除
  local host_ip=$(ggrep -oP '127\.0\.0\.\d+$' $HOME/projects/$project_name/dev/.env)
  local line_count=$(ggrep -noP "^$host_ip" /etc/hosts | awk -F ':' '{print $1}')
  local delete_line_start=$( (expr $line_count - 1))
  local delete_line_end=$( (expr $line_count + 1))
  echo 'honoka' | sudo -S -p '' zsh -c "sed -i '' \"${delete_line_start},${delete_line_end}d\" /etc/hosts"

  # ディレクトリの削除
  cd $HOME/projects
  rm -rf $HOME/projects/$project_name

  echo 'Octopusプロジェクトの破棄が完了しました。'
}
