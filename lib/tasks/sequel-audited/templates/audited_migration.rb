Sequel.migration do
  change do
    create_table :audit_logs do
      primary_key :id
      column :model_type,       String
      column :model_pk,         Integer
      column :event,            String
      column :changed,          :text
      column :version,          Integer, default: 0
      column :created_at,       :timestamp

      index :created_at

      # column :user_id,          Integer
      # column :username,         String
      # column :user_type,        String
    end
  end
end
