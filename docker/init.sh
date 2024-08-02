#!/bin/bash

CHAINID="$CHAINID"
MONGODB_CONNECTION_STRING="$MONGODB_CONNECTION_STRING"
COMMIT_CHAIN_RPC_URL="$COMMIT_CHAIN_RPC_URL"
COMMIT_CHAIN_WS_URL="$COMMIT_CHAIN_WS_URL"
USER_AND_GID_INFO="$USER_AND_GID_INFO"

show_current_environment_variables() {
  declare -p \
     CHAINID \
     MONGODB_CONNECTION_STRING \
     COMMIT_CHAIN_RPC_URL \
     COMMIT_CHAIN_WS_URL \
     USER_AND_GID_INFO
}

check_environment_variables(){
  # Check if CHAIN_ID is defined
  if [ -z $CHAINID ]; then
    echo "Error: CHAINID is not defined. Please provide CHAINID as an argument. Example: make up-rayls CHAINID=xxxxxxxxxx MONGODB_CONNECTION_STRING='mongodb+srv://username:password@endpoint' COMMIT_CHAIN_RPC_URL=http://commit-chain-rpc-url:8545 COMMIT_CHAIN_WS_URL=ws://commit-chain-ws-url:8546"
    exit 1
  fi

  if [[ -n $MONGODB_CONNECTION_STRING ]]; then  
    MONGODB_CONNECTION_STRING="$MONGODB_CONNECTION_STRING" 
  else
    echo "Warning: MONGODB_CONNECTION_STRING is not defined. Using local MongoDB." >&2 
  fi

  # Check if COMMIT_CHAIN_RPC_URL is defined
  if [ -z $COMMIT_CHAIN_RPC_URL ]; then
    echo "Error: COMMIT_CHAIN_RPC_URL is not defined. Please provide COMMIT_CHAIN_RPC_URL as an argument. Example:make up-rayls CHAINID=xxxxxxxxxx MONGODB_CONNECTION_STRING='mongodb+srv://username:password@endpoint' COMMIT_CHAIN_RPC_URL=http://commit-chain-rpc-url:8545 COMMIT_CHAIN_WS_URL=ws://commit-chain-ws-url:8546" 
    exit 1
  fi

  # Check if COMMIT_CHAIN_WS_URL is defined
  if [ -z $COMMIT_CHAIN_WS_URL ]; then
    echo "Error: COMMIT_CHAIN_WS_URL is not defined. Please provide COMMIT_CHAIN_WS_URL as an argument. Example: make up-rayls CHAINID=xxxxxxxxxx MONGODB_CONNECTION_STRING='mongodb+srv://username:password@endpoint' COMMIT_CHAIN_RPC_URL=http://commit-chain-rpc-url:8545 COMMIT_CHAIN_WS_URL=ws://commit-chain-ws-url:8546" 
    exit 1
  fi
}

create_dirs(){
mkdir -pv ./rayls/privacy-ledger/data/rayls-private-ledger
mkdir -pv ./rayls/privacy-ledger/var
mkdir -pv ./rayls/relayer/var
#mkdir -p ./rayls
#mkdir -p ./rayls/privacy-ledger/data ./rayls/privacy-ledger/var ./rayls/relayer/var
}

setup_config(){
  create_dirs
  setup_privacy_ledger_genesis_json
  setup_privacy_ledger_config_toml
  setup_privacy_ledger_start_sh
  setup_relayer_config_json
}

# generate privacy-ledger...genesis.json
setup_privacy_ledger_genesis_json() {
cat <<EOF > ./rayls/privacy-ledger/var/genesis.json
{
  "config": {
   "chainId": $CHAINID,
   "homesteadBlock": 0,
   "eip150Block": 0,
   "eip155Block": 0,
   "eip158Block": 0,
   "byzantiumBlock": 0,
   "constantinopleBlock": 0,
   "petersburgBlock": 0,
   "istanbulBlock": 0,
   "berlinBlock": 0,
   "ethash": {}
  },
  "difficulty": "1",
  "gasLimit": "9000000000000",
  "alloc": {
    "0x5f2E7061aDd05c8B4C2b48054E5A591eFFa270Aa": {
      "balance": "300000000000000000000000"
    }
  }
}
EOF
}

# generate privacy-ledger...config.toml
setup_privacy_ledger_config_toml() {
cat <<EOF > ./rayls/privacy-ledger/var/config.toml
[Eth]
RPCGasCap = 9000000000000

[Eth.Ethash]
DisallowBlockCreation = false
Difficulty= 100000
CacheDir = "ethash"
CachesInMem = 2
CachesOnDisk = 3
CachesLockMmap = false
DatasetDir = "/app/data/rayls-private-ledger/.ethash"
DatasetsInMem = 1
DatasetsOnDisk = 2
DatasetsLockMmap = false
PowMode = 0
NotifyFull = false
EOF
}

# generate privacy-ledger...start.sh
setup_privacy_ledger_start_sh() {
cat <<EOF > ./rayls/privacy-ledger/var/start.sh
#!/bin/sh

/app/raylz-private-ledger\
  --http\
  --http.vhosts="*"\
  --http.addr="0.0.0.0"\
  --http.api="net,web3,eth,debug,txpool"\
  --http.port 8545\
  --http.corsdomain="*"\
  --ipcdisable\
  --ws\
  --ws.addr="0.0.0.0"\
  --ws.port 8660\
  --ws.api eth,net,web3\
  --ws.origins="*"\
  --datadir="/app/data/rayls-private-ledger"\
  --networkid="$CHAINID"\
  --mine\
  --miner.threads=1\
  --miner.etherbase="0x1bE478ee83095aF7F21bd84743fB39B68Dd600A6"\
  --metrics\
  --pprof\
  --metrics.addr=0.0.0.0\
  --metrics.port=6080\
  --pprof.addr=0.0.0.0\
  --rpc.gascap=0\
  --gcmode="archive"\
  --syncmode=full\
  --miner.gasprice=0\
  --port=30309\
  --config=/app/var/config.toml\
  --db.engine=mongodb\
  --db.engine.host="\${MONGODB_CONN}"\
  --db.engine.name="\${MONGODB_DATABASE}"\
  /app/var/genesis.json
EOF
chmod +x ./rayls/privacy-ledger/var/start.sh
}

setup_relayer_config_json() {
  # generate relayer...config.json
cat <<EOF > ./rayls/relayer/var/config.json
{
  "Database": {
      "ConnectionString": "\${RELAYER_DATABASE_CONNECTIONSTRING}",
      "Name": "\${RELAYER_DATABASE_NAME}",
      "Type": "\${RELAYER_DATABASE_TYPE}"
  },
  "Blockchain": {
      "ChainID": "\${RELAYER_BLOCKCHAIN_CHAINID}",
      "ChainURL": "\${RELAYER_BLOCKCHAIN_CHAINURL}",
      "ChainWSURL": "\${RELAYER_BLOCKCHAIN_CHAINWSURL}",
      "BatchSize": "\${RELAYER_BLOCKCHAIN_BATCHSIZE}",
      "PlStartingBlock": "0"
  },
  "CommitChain": {
    "ChainURL": "\${RELAYER_COMMITCHAIN_CHAINURL}",
    "ChainWSUrl": "\${RELAYER_COMMITCHAIN_CHAINWSURL}",
    "CommitChainPLStorageContract": "\${RELAYER_COMMITCHAIN_COMMITCHAINPLSTORAGECONTRACT}",
    "ParticipantStorageContract": "\${RELAYER_COMMITCHAIN_PARTICIPANTSTORAGECONTRACT}",
    "ChainId": "\${RELAYER_COMMITCHAIN_CHAINID}",
    "CcStartingBlock": "\${RELAYER_COMMITCHAIN_CCSTARTINGBLOCK}",
    "CcAtomicRevertStartingBlock": "\${RELAYER_COMMITCHAIN_ATOMICREVERTSTARTINGBLOCK}",
    "Version": "\${RELAYER_COMMITCHAIN_VERSION}",
    "AtomicTeleportContract": "\${RELAYER_COMMITCHAIN_ATOMICTELEPORTCONTRACT}",
    "ResourceRegistryContract": "\${RELAYER_COMMITCHAIN_RESOURCEREGISTRYCONTRACT}",
    "CcEndpointAddress": "\${RELAYER_COMMITCHAIN_CCENDPOINTADDRESS}",
    "BalanceCommitmentContract": "\${RELAYER_COMMITCHAIN_BALANCECOMMITMENTCONTRACT}",
    "TokenRegistryContract": "\${RELAYER_COMMITCHAIN_TOKENREGISTRYCONTRACT}",
    "OperatorChainId": "\${RELAYER_COMMITCHAIN_OPERATORCHAINID}"
  }
}
EOF
  #informative_output
}

setup_docker_compose() {
  if [ -z "$USER_AND_GID_INFO" ]; then
    USER_AND_GID_INFO=$(id | tr ')(=,' ' '  | awk '{ print $2":"$5 }')
  fi
  1>&2 echo "using $USER_AND_GID_INFO for USER:GID setting for mongo docker"

  if [ -z "$MONGODB_CONNECTION_STRING" ]; then
    cp ./examples/docker-compose.yml.mongodb docker-compose.yml
    sed -i "s|BLOCKCHAIN_CHAIN_ID|$CHAINID|g" docker-compose.yml
    sed -i "s|COMMIT_CHAIN_RPC_URL|$COMMIT_CHAIN_RPC_URL|g" docker-compose.yml
    sed -i "s|COMMIT_CHAIN_WS_URL|$COMMIT_CHAIN_WS_URL|g" docker-compose.yml
    mkdir -pv mongodb/data
  else
    cp ./examples/docker-compose.yml.example docker-compose.yml
    sed -i "s|BLOCKCHAIN_CHAIN_ID|$CHAINID|g" docker-compose.yml
    sed -i "s|MONGODB_CONNECTION_STRING|$MONGODB_CONNECTION_STRING|g" docker-compose.yml
    sed -i "s|COMMIT_CHAIN_RPC_URL|$COMMIT_CHAIN_RPC_URL|g" docker-compose.yml
    sed -i "s|COMMIT_CHAIN_WS_URL|$COMMIT_CHAIN_WS_URL|g" docker-compose.yml
  fi

  if [ -n "$USER_AND_GID_INFO" ]; then
    sed -i "s|USER:GID|$USER_AND_GID_INFO|g" docker-compose.yml
  else
    sed -i '/user:/d ; /USER:GID/d' examples/docker-compose.yml.mongodb
  fi
  1>&2 echo "docker-compose.yml file (re)generated"
}


setup_dirs_user_and_gid() {
  if [ -z "$USER_AND_GID_INFO" ]; then
    USER_AND_GID_INFO=$(id | tr ')(=,' ' '  | awk '{ print $2":"$5 }')
  fi
  1>&2 echo "using $USER_AND_GID_INFO for USER:GID for dirs"
  if [ -n "$USER_AND_GID_INFO" ]; then
    chown -Rc $USER_AND_GID_INFO .
  fi
}

informative_output(){
  echo "Directories created:"
  echo "./rayls/privacy-ledger/data"
  echo "./rayls/privacy-ledger/var"
  echo "./rayls/relayer/var"
  echo ""
  
  echo "Files created:"
  echo "./rayls/privacy-ledger/var/genesis.json"
  echo "./rayls/privacy-ledger/var/config.toml"
  echo "./rayls/privacy-ledger/var/start.sh"
  echo "./docker-compose.yml"
  echo ""
  
  echo "CHAINID was updated in the following files:"
  echo "./rayls/privacy-ledger/var/genesis.json"
  echo "./rayls/privacy-ledger/var/start.sh"
  echo ""

}

starting_environment(){
  echo "Starting Rayls Environment!"
  if [ -z "$MONGODB_CONNECTION_STRING" ]; then
    docker compose up -d mongodb && sleep 40
    docker compose up -d privacy-ledger && sleep 15
    docker compose up -d relayer
    docker compose logs privacy-ledger relayer -f
  else
    docker compose up -d privacy-ledger && sleep 15
    docker compose up -d relayer
    docker compose logs privacy-ledger relayer -f
  fi
}


if [ -z "$1" ]; then
  ${NOOP+echo} check_environment_variables
  ${NOOP+echo} create_dirs
  ${NOOP+echo} setup_config
  ${NOOP+echo} setup_docker_compose
  ${NOOP+echo} setup_dirs_user_and_gid
   ${NOOP+echo} informative_output
  ${NOOP+echo} starting_environment
else
  ${NOOP+echo} $*
fi
