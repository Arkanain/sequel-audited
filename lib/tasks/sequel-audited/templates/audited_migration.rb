Sequel.migration do
  change do
    create_table(:audited_logs) do
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
      
      
      # column :audited_id,       :integer
      # column :audited_type,     :string
      # column :associated_id,    :integer
      # column :associated_type,  :string
      # column :action,           :string
      
      # column :auditable_id,     :integer
      # column :auditable_type,   :string
      # column :associated_id,    :integer
      # column :associated_type,  :string
      # column :user_id,          :integer
      # column :user_type,        :string
      # column :username,         :string
      # column :action,           :string
      # column :audited_changes,  :text
      # column :version,          :integer, :default => 0
      # column :comment,          :string
      # column :remote_address,   :string
      # column :request_uuid,     :string
      # column :created_at,       :datetime
      #
      # add_index :audits, [:auditable_id, :auditable_type], :name => 'auditable_index'
      # add_index :audits, [:associated_id, :associated_type], :name => 'associated_index'
      # add_index :audits, [:user_id, :user_type], :name => 'user_index'
      # add_index :audits, :request_uuid
      index :created_at
    end
  end
end
