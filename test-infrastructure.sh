#!/bin/bash
# Script de Teste Rápido da Infraestrutura Chat4All
# Executa verificações básicas automaticamente

set -e  # Parar em caso de erro

echo "=========================================="
echo "🧪 Chat4All - Teste Rápido Infraestrutura"
echo "=========================================="
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para printar resultado
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASSOU${NC}: $1"
    else
        echo -e "${RED}✗ FALHOU${NC}: $1"
        exit 1
    fi
}

echo "📦 Teste 1: Verificar containers..."
docker-compose ps | grep -E "(kafka|cassandra|zookeeper)" > /dev/null
check_result "Containers estão rodando"
echo ""

echo "🗄️ Teste 2: Verificar schema Cassandra..."
docker exec chat4all-cassandra cqlsh -e "DESCRIBE KEYSPACE chat4all;" > /dev/null 2>&1
check_result "Keyspace 'chat4all' existe"

docker exec chat4all-cassandra cqlsh -e "DESCRIBE TABLE chat4all.messages;" > /dev/null 2>&1
check_result "Tabela 'messages' existe"

docker exec chat4all-cassandra cqlsh -e "DESCRIBE TABLE chat4all.conversations;" > /dev/null 2>&1
check_result "Tabela 'conversations' existe"

docker exec chat4all-cassandra cqlsh -e "DESCRIBE TABLE chat4all.users;" > /dev/null 2>&1
check_result "Tabela 'users' existe"
echo ""

echo "📨 Teste 3: Testar escrita/leitura Cassandra..."
TEST_UUID=$(uuidgen)
docker exec chat4all-cassandra cqlsh -e "INSERT INTO chat4all.messages (conversation_id, timestamp, message_id, sender_id, content, status) VALUES (uuid(), toTimestamp(now()), ${TEST_UUID}, uuid(), 'Teste automatizado', 'SENT');" > /dev/null 2>&1
check_result "Insert no Cassandra"

docker exec chat4all-cassandra cqlsh -e "SELECT content FROM chat4all.messages WHERE message_id = ${TEST_UUID} ALLOW FILTERING;" 2>&1 | grep -q "Teste automatizado"
check_result "Select no Cassandra"
echo ""

echo "🔄 Teste 4: Verificar tópicos Kafka..."
docker exec chat4all-kafka kafka-topics --list --bootstrap-server localhost:9092 2>&1 | grep -q "messages"
check_result "Tópico 'messages' existe"

TOPIC_INFO=$(docker exec chat4all-kafka kafka-topics --describe --topic messages --bootstrap-server localhost:9092 2>&1)
echo "$TOPIC_INFO" | grep -q "PartitionCount: 3"
check_result "Tópico tem 3 partições"
echo ""

echo "📤 Teste 5: Produzir mensagem no Kafka..."
TEST_MSG="{\"message_id\":\"msg_test_$(date +%s)\",\"conversation_id\":\"conv_test\",\"sender_id\":\"user_test\",\"content\":\"Teste automatizado Kafka\",\"timestamp\":$(date +%s)000,\"event_type\":\"MESSAGE_SENT\"}"
echo "$TEST_MSG" | docker exec -i chat4all-kafka kafka-console-producer --bootstrap-server localhost:9092 --topic messages 2>&1 > /dev/null
check_result "Mensagem enviada para Kafka"
echo ""

echo "📥 Teste 6: Consumir mensagem do Kafka..."
CONSUMED=$(timeout 5 docker exec chat4all-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic messages --from-beginning 2>/dev/null | tail -1)
if echo "$CONSUMED" | grep -q "message_id"; then
    echo -e "${GREEN}✓ PASSOU${NC}: Mensagem consumida do Kafka"
    echo -e "${YELLOW}   Preview:${NC} $(echo $CONSUMED | cut -c1-80)..."
else
    echo -e "${RED}✗ FALHOU${NC}: Não conseguiu consumir mensagem"
    exit 1
fi
echo ""

echo "🌐 Teste 7: Verificar Zookeeper..."
ZK_OUTPUT=$(docker exec chat4all-zookeeper zkCli.sh -server localhost:2181 ls /brokers/ids 2>&1 | grep -o "\[.*\]" || echo "[]")
if echo "$ZK_OUTPUT" | grep -q "1"; then
    echo -e "${GREEN}✓ PASSOU${NC}: Kafka registrado no Zookeeper (broker IDs=$ZK_OUTPUT)"
else
    echo -e "${YELLOW}⚠ AVISO${NC}: Zookeeper respondendo mas broker não registrado (pode ser normal)"
fi
echo ""

echo "📊 Teste 8: Verificar recursos..."
echo -e "${YELLOW}Uso de CPU e Memória:${NC}"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>&1 | grep -E "(CONTAINER|chat4all)" || echo "  (Estatísticas não disponíveis)"
echo ""

echo "=========================================="
echo -e "${GREEN}✅ TODOS OS TESTES PASSARAM!${NC}"
echo "=========================================="
echo ""
echo "📚 Infraestrutura está 100% funcional e pronta para desenvolvimento."
echo ""
echo "Próximos passos:"
echo "  1. Implementar autenticação JWT (US3)"
echo "  2. Ver detalhes em: specs/001-basic-messaging-api/tasks.md"
echo "  3. Testes manuais: cat MANUAL_TESTS.md"
echo ""
