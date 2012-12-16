module DB
  @@options = { :host => "localhost", :username => "root", :password => "cut", :database => "RFFI100000", :encoding => 'utf8' }

  @@description = 
  {
  DirectionClassifier: {
      columns: {
        name: 'VARCHAR(20)'
      },
      primary_key: 'id',
      foreign_keys: []
    },
    Reasons: {
      columns: {
        message: 'VARCHAR(300)'
      },
      primary_key: 'id',
      foreign_keys: []
    },
    GrantArchive: {
      columns: {
        direction_id: 'INT',
        approved_date: 'DATE',
        research_theme: 'VARCHAR(30)',
        head_name: 'VARCHAR(30)',
        contributors_number: 'INT',
        amount_requested: 'DEC(8,2)',
        amount_received: 'DEC(8,2)'
      },
      primary_key: 'id',
      foreign_keys: [['direction_id', 'DirectionClassifier (id)', 'ON UPDATE CASCADE ON DELETE CASCADE']]
    },
    QueryArchive: {
      columns: {
        query_date: 'DATE',
        direction_id: 'INT',
        research_theme: 'VARCHAR(30)',
        head_name: 'VARCHAR(30)',
        contributors_number: 'INT',
        amount_requested: 'DEC(8,2)',
        organisation: 'VARCHAR(30)',
        address: 'VARCHAR(30)',
        approved: 'INT'
      },
      primary_key: 'id',
      foreign_keys: [['direction_id', 'DirectionClassifier (id)', 'ON UPDATE CASCADE ON DELETE CASCADE'], ['approved', 'Reasons (id)', '']]
    },
    GrantResults: {
      columns: {
        grant_id: 'INT',
        success: 'BOOL'
      },
      primary_key: 'id',
      foreign_keys: [['grant_id', 'GrantArchive (id)', 'ON UPDATE CASCADE ON DELETE CASCADE']]
    },
    BudgetAndDeadline: {
      columns: {
        budget: 'DEC(8,2)',
        remaining_budget: 'DEC(8,2)',
        deadline: 'DATE'
      },
      primary_key: 'id',
      foreign_keys: []
    }
  }

  def self.options
    @@options
  end

  def self.generate(client, rows)
    @@description.each do |table_name, table_des|
      client.query("SET FOREIGN_KEY_CHECKS = 0"); client.query("DROP TABLE IF EXISTS #{table_name.to_s}"); client.query("SET FOREIGN_KEY_CHECKS = 1")
      query = "CREATE TABLE #{table_name.to_s} (id INT AUTO_INCREMENT, "
      table_des[:columns].each { |column_name, column_type| query += "#{column_name.to_s} #{column_type}, " }
      query += "PRIMARY KEY(#{table_des[:primary_key]}), "
      table_des[:foreign_keys].each { |foreign_key| query += "FOREIGN KEY (#{foreign_key[0]}) REFERENCES #{foreign_key[1]} #{foreign_key[2]}, " }
      query = query[0..-3] + ") DEFAULT CHARSET=utf8"
      puts query
      client.query(query)
      rows[table_name].times do
        query = "INSERT INTO #{table_name.to_s} ("
        table_des[:columns].each { |column_name, column_type| query += "#{column_name}, " }
        query = query[0..-3] + ") VALUES ("
        table_des[:columns].each { |column_name, column_type| query += "#{self.random(column_type)}, " }
        query = query[0..-3] + ")"
        puts query
        client.query(query)
      end
    end
  end

  def self.random(type)
    case type
    when 'INT'
      p = rand(1..20)
      p % 3 == 0 ? 1 : p
    when 'BOOL'
      rand(2)
    when 'DATE'
      ['DATE_SUB(DATE(NOW()), INTERVAL 1 WEEK)', 'DATE_ADD(DATE(NOW()), INTERVAL 1 WEEK)', 'DATE(NOW())'].sample
    when /DEC\((.*)\)/
      num = 0
      f, d = /\((.*)\)/.match(type)[0][1..-2].split ','
      rand((1..f.to_i)).times { |i| num += rand(1..9) * 10.0**(i-1) }
      rand(d.to_i).times { |i| num += rand(1..9) * 10.0**(-i) }
      num
    when /VARCHAR\((.*)\)/
      f = /\((.*)\)/.match(type)[0][1..-2].to_i
      "'#{('a'..'z').to_a.sample(rand((3..f))).join.capitalize}'"
    end
  end

end