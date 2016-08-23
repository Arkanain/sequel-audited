require 'rake/file_utils'

namespace :audited do
  namespace :migrate do
    desc 'Installs Sequel::Audited migration, but does not run it'
    task :install do
      FileUtils.cp(
        "#{File.dirname(__FILE__)}/templates/audited_migration.rb",
        "#{Dir.pwd}/db/migrate/#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_create_audited_table.rb"
      )
    end
    
    desc 'Updates existing Sequel::Audited migration files with amendments'
    task :update do
      puts 'TODO: no updates required yet'
    end
  end
end