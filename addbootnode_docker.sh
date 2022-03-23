#!/bin/bash
if [ -f /etc/systemd/system/masad.service ]
then
echo -e "Вы установили ноду как сервис, этот скрипт вам не поможет, он для докера.\nYou have masad.service but this script for docker!"
exit
fi

read -p "Введите бутноду(или несколько через запятую без пробелов) (Enter a bootnode). example: enode://165bda16bad61xbd6ab165axdb613bd61ba6d1b3a:30300 : "  enode
while [ "$enode" == "" ]
do
read -p "ВНИМАТЕЛЬНО ВВЕДИТЕ БУТНОДУ (Enter a bootnode). example: enode://165bda16bad61xbd6ab165axdb613bd61ba6d1b3a:30300 : "  enode
done
echo "Вы ввели (You entered): $enode"

if [ -n "$(cat /etc/passwd | grep /home/masa:/usr/sbin/nologin)" ]
then
echo "masa user found"
user="masa"
dir="/home/masa"
else 
user="root"
dir="$HOME"
fi

tee /$user/masa-node-v1.0/docker-compose.yml > /dev/null <<EOF
# Masa Testnet Node v1.0

version: "3.6"
x-masa-testnet-node-v10-def:
  &masa-testnet-node-v10-def
  restart: "on-failure"
  image: "\${MASA_DOCKER_IMAGE:-quorumengineering/quorum:22.1}"
  expose:
    - "21000"
    - "50400"
  healthcheck:
    test: ["CMD", "wget", "--spider", "--proxy", "off", "http://localhost:8545"]
    interval: 3s
    timeout: 3s
    retries: 10
    start_period: 5s
  labels:
    com.masa.consensus: \${MASA_CONSENSUS:-istanbul}
  entrypoint:
    - /bin/sh
    - -c
    - |
      DDIR=/qdata/dd
      GENESIS_FILE="/network/genesis.json"
      CONSENSUS_RPC_API="istanbul"
      NETWORK_ID=\$\$(cat \$\${GENESIS_FILE} | grep chainId | awk -F " " '{print \$\$2}' | awk -F "," '{print \$\$1}')
      GETH_ARGS_istanbul="--emitcheckpoints --istanbul.blockperiod 1 --mine --miner.threads 1 --syncmode full"
      if [ ! -f \$\${DDIR}/control_file ]; then
        mkdir -p \$\${DDIR}/keystore
        mkdir -p \$\${DDIR}/geth
        geth --datadir \$\${DDIR} init \$\${GENESIS_FILE}
        echo "Created \$\$(date)" > \$\${DDIR}/control_file
      fi
      geth \\
        --identity node\$\${NODE_ID}-\${MASA_CONSENSUS:-istanbul} \\
        --datadir \$\${DDIR} \\
        --bootnodes $enode,enode://ac6b1096ca56b9f6d004b779ae3728bf83f8e22453404cc3cef16a3d9b96608bc67c4b30db88e0a5a6c6390213f7acbe1153ff6d23ce57380104288ae19373ef@54.146.254.245:21000 \\
        --verbosity 5 \\
        --networkid \$\${NETWORK_ID} \\
        --http \\
        --http.corsdomain "*" \\
        --http.vhosts "*" \\
        --http.addr 0.0.0.0 \\
        --http.port 8545 \\
        --http.api admin,eth,debug,miner,net,shh,txpool,personal,web3,quorum,\$\${CONSENSUS_RPC_API} \\
        --port 21000 \\
        --nousb \\
        \${MASA_GETH_ARGS:-} \$\${GETH_ARGS_\${MASA_CONSENSUS:-istanbul}}
services:
  ui:
    extends:
      file: ./ui/docker-compose.yml
      service: ui
  masa-node:
    << : *masa-testnet-node-v10-def
    hostname: masa-node
    ports:
      - "22001:8545"
    volumes:
      - vol1:/qdata
      - ./network/testnet:/network:ro
    environment:
      - PRIVATE_CONFIG=\${PRIVATE_CONFIG:-/qdata/tm/tm.ipc}
      - NODE_ID=1
    networks:
      masa-testnet:
        ipv4_address: 172.16.240.20
networks:
  masa-testnet:
    name: masa-testnet
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: 172.16.240.0/24
volumes:
  "vol1":
EOF
echo "Бутнода добавлена (Bootnode added)"
echo "Перезапускаем докер... (Restarting docker image...)"
cd /$user/masa-node-v1.0/ && docker-compose down && PRIVATE_CONFIG=ignore docker-compose up -d && cd $HOME
echo "DONE"
