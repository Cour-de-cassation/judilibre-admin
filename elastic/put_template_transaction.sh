curl -XPUT "${elasticsearch_node}/_template/t_transaction" -H 'Content-Type: application/json' -d @template_transaction.json
