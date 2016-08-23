Sequel.migration do
  change do
    create_table :audit_logs do
      primary_key :id
      column :model,            String
      column :model_pk,         String
      column :event,            String
      column :changed,          :text
      column :version,          Integer, default: 0
      column :user_id,          Integer
      column :username,         String
      column :user_type,        String
      column :created_at,       :timestamp

      index :created_at
    end
  end
end
