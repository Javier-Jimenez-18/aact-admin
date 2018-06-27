module Util
  class UserDbManager < DbManager

    def self.change_password(user, pwd)
      new.change_password(user, pwd)
    end

    def create_user_account(user)
      #begin
        return false if !can_create_user_account?(user)
        Public::Study.connection.execute("create user \"#{user.username}\" password '#{user.password}';")
        Public::Study.connection.execute("alter user #{user.username} nologin;")  # can't login until they confirm their email
        return true
      #rescue => e
      #  user.errors.add(:base, e.message)
      #  return false
      #end
    end

    def can_create_user_account?(user)
      return false if user_account_exists?(user.username)
      return false if !public_db_accessible?
      return true
    end

    def user_account_exists?(username)
      return true if username == 'postgres'
      return true if username == 'ctti'
      x=Public::Study.connection.execute("SELECT usename FROM pg_catalog.pg_user where usename = '#{username}' UNION
                  SELECT groname  FROM pg_catalog.pg_group where groname = '#{username}'").count > 0
      puts "======================="
      puts Public::Study.connection.current_database
      puts x
      puts "======================="
      x
    end

    def remove_user(username)
      begin
        return false if !user_account_exists?(username)
        revoke_db_privs(username)
        Public::Study.connection.execute("reassign owned by #{username} to postgres;")
        Public::Study.connection.execute("drop owned by #{username};")
        Public::Study.connection.execute("drop user #{username};")
        return true
      rescue => e
        raise e
      end
    end

    def change_password(user,pwd)
      begin
         Public::Study.connection.execute("alter user \"#{user.username}\" password '#{pwd}';")
      rescue => e
        user.errors.add(:base, e.message)
      end
    end

    def backup_user_info
      fm=Util::FileManager.new
      file_prefix="#{fm.backup_directory}/#{Time.zone.now.strftime('%Y%m%d')}"

      table_file_name="#{file_prefix}_aact_users_table.sql"
      event_file_name="#{file_prefix}_aact_user_events.sql"
      account_file_name="#{file_prefix}_aact_user_accounts.sql"

      File.delete(table_file_name) if File.exist?(table_file_name)
      File.delete(event_file_name) if File.exist?(event_file_name)
      File.delete(account_file_name) if File.exist?(account_file_name)

      log "dumping Users table..."
      cmd="pg_dump --no-owner --host=localhost -U #{ENV['DB_SUPER_USERNAME']} --table=Users  --data-only aact_dmin > #{table_file_name}"
      run_command_line(cmd)

      log "dumping User events..."
      cmd="pg_dump --no-owner --host=localhost -U #{ENV['DB_SUPER_USERNAME']} --table=User_Events  --data-only aact_admin > #{event_file_name}"
      run_command_line(cmd)

      log "dumping User accounts..."
      cmd="/opt/rh/rh-postgresql96/root/bin/pg_dumpall -U  #{ENV['DB_SUPER_USERNAME']} -h #{public_host_name} --globals-only > #{account_file_name}"
      run_command_line(cmd)

      event=UserEvent.new({:event_type=>'backup', :file_names=>" #{table_file_name}, #{event_file_name}, #{account_file_name}" })
      UserMailer.send_backup_notification(event)
    end

    def grant_db_privs(username)
      Public::Study.connection.execute("alter role \"#{username}\" IN DATABASE aact set search_path = ctgov;")
      Public::Study.connection.execute("grant connect on database aact to \"#{username}\";")
      Public::Study.connection.execute("grant usage on schema ctgov TO \"#{username}\";")
      Public::Study.connection.execute("grant select on all tables in schema ctgov to \"#{username}\";")
      Public::Study.connection.execute("alter user \"#{username}\" login;")
    end

    def revoke_db_privs(username)
      terminate_sessions_for(username)
      Public::Study.connection.execute("alter user #{username} nologin;")
    end

    def terminate_sessions_for(username)
       Public::Study.connection.select_all("select * from pg_stat_activity order by pid;").each { |session|
        if session['usename']=="#{username}"
          Public::Study.execute("select pg_terminate_backend(#{session['pid']})")
        end
      }
    end
  end
end