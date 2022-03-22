#!/bin/bash
if [ ! -f /etc/systemd/system/masad.service ]
then
echo -e "Файл сервиса не найден! Сначала установите ноду как сервис.\nService file not found! Setup the node as service first."
exit
fi

read -p "Введите имя своей ноды (Enter your node name): "  nodename
while [ "$nodename" == "" ]
do
read -p "ВНИМАТЕЛЬНО ВВЕДИТЕ ИМЯ НОДЫ (Enter your node name): "  nodename
done
echo "Вы ввели (You entered): $nodename"
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

tee /etc/systemd/system/masad.service > /dev/null <<EOF
[Unit]
Description=MASA
After=network.target
[Service]
Type=simple
User=$user
ExecStart=/usr/local/bin/geth --identity $nodename --datadir $dir/masa-node-v1.0/data --bootnodes $enode,enode://91a3c3d5e76b0acf05d9abddee959f1bcbc7c91537d2629288a9edd7a3df90acaa46ffba0e0e5d49a20598e0960ac458d76eb8fa92a1d64938c0a3a3d60f8be4@54.158.188.182:21000 --emitcheckpoints --istanbul.blockperiod 10 --mine --miner.threads 1 --syncmode full --verbosity 4 --networkid 190250 --rpc --rpccorsdomain "*" --rpcvhosts "*" --rpcaddr 127.0.0.1 --rpcport 8545 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,istanbul --port 30300 
Restart=on-failure
RestartSec=10
LimitNOFILE=4096
Environment="PRIVATE_CONFIG=ignore"
[Install]
WantedBy=multi-user.target
EOF
echo "Бутнода добавлена (Bootnode added)"
sudo systemctl daemon-reload
echo "Перезапускаем сервис... (Restarting service...)"
sudo systemctl restart masad
echo "Сервис перезапущен"
