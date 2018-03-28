Sequel.migration do
  change do
    create_table :node_transactions do
      primary_key :id
      String :type, size: 11
      String :node_id, size: 10
      Integer :node_envelope_id, index: true
      Time :updated_at
      Time :created_at
    end
  end
end
