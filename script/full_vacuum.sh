#!/usr/bin/env bash
#######################################################################################################################################
# Programa .....: full_vacuum_v1.sh
# Autor ........: Cleiton Maia (cleiton.maia@gmail.com)
# Data Criação .: 31/08/2023
# Atualização ..:
# Descrição ....: Executar a rotina de VACUUM FULL nas 20 maiores tabelas do banco de dados, as tabelas são elencadas automaticamente
#######################################################################################################################################

#---[ Environment Variables ]
source /root/.bashrc
logDirectory="/var/tmp"
logFile="$logDirectory/$(basename -s .sh "$0").log"
logDate=$(TZ=":America/Fortaleza" date +%d-%m-%Y)
dayWeekName=$(TZ=":America/Fortaleza" date +%a)
lastSun=$(cal | awk '{print $1}' | grep '[0-9]' | tail -n1)
currentDay=$(date +%e)
appVersion=2.1.0
appName=$(basename "$0")
export PGPASSWORD=$vDBSenha
export TERM=xterm

#---[ System Function ]
functionBanner() {
  echo   ""
  echo   "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
  echo   "║                                                                                                                        ║"
  printf "║$(tput bold) %-118s $(tput sgr0)║\n" "$@"
  echo   "║                                                                                                                        ║"
  echo   "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
  echo ""
}

#---[ Log control and Validations ]
[[ ! -f "$logFile" ]] && : > "$logFile"
totalLines=$(wc -l < "$logFile")
[[ "$totalLines" -ge 500 ]] && sed -i '1,100d' "$logFile"

pgrep -f "^$appName$" &>/dev/null && {
    functionBanner ">>>>> $appName is running <<<<<"
    exit 1
}

if [[ -z "$vDBHost" || -z "$vDBUser" || -z "$vDBNome" || -z "$vDBSenha" ]]; then
    echo "Error: Variable not set."
    exit 1
fi

#---[ Start Procedure ]
if [ $lastSun -eq $currentDay ]; then
  psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -t -A -c "SELECT esquema || '.' || tabela tabela FROM (SELECT tablename AS tabela, schemaname AS esquema, schemaname||'.'||tablename AS esq_tab FROM pg_catalog.pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') ) AS x ORDER BY pg_total_relation_size(esq_tab) DESC LIMIT 40;" > $logDirectory/listtables.dat
  while read idTable; do
    if [ -n "$idTable" ]; then
      clear
      initialTime=$(TZ=":America/Fortaleza" date +%T)
      functionBanner ">>>>> Starting process VACUUM FULL <<<<<" \
                     ""                                         \
                     "Database Name ..: $vDBNome"               \
                     "Table Name .....: $idTable"
      initialTimeSum=$(TZ=":America/Fortaleza" date  +%s)
      sizeBefore=$(psql -h "$vDBHost" -U "$vDBUser" -d "$vDBNome" -t -A -c "SELECT pg_size_pretty(pg_total_relation_size('$idTable'));")
      psql -h "$vDBHost" -U "$vDBUser"  -d "$vDBNome" -c "VACUUM (FULL, VERBOSE, ANALYZE, TRUNCATE) $idTable ; "
      sizeAfter=$(psql -h "$vDBHost" -U "$vDBUser" -d "$vDBNome" -t -A -c "SELECT pg_size_pretty(pg_total_relation_size('$idTable'));")
      finishTime=$(TZ=":America/Fortaleza" date +%T)
      finalTimeSum=$(TZ=":America/Fortaleza" date  +%s)
      totalRecordSum=$(( finalTimeSum - initialTimeSum ))
      totalTime=$(date -d @$totalRecordSum +%H:%M:%S)
      echo "Day: $dayWeekName [$currentDay] - Table: $idTable - Size: $sizeBefore-$sizeAfter - Date: $logDate Started: $initialTime Finished: $finishTime Total Time: $totalTime" >> "$logFile"
    fi
  done < $logDirectory/listtables.dat
fi
