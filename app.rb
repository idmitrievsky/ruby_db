# coding: utf-8
require 'sinatra'
require 'haml'
require 'mysql2'
require 'benchmark'
require './helpers/DB'

# 1 на рассмотрении
# 2 принята
# 3 после дедлайна
# 4 не выполнил или уже есть
# 5 фуфло

configure { set :server, :puma }
set :haml, :format => :html5

client = Mysql2::Client.new(DB.options)

def stats(client)
  stats = []
  client.query('SELECT budget, remaining_budget, deadline FROM BudgetAndDeadline WHERE id = 1').each do |row|
    row.each {|key, val| stats << val}
  end
  stats
end

get '/' do
  redirect to('/choose')
end

get '/choose' do
  query = "SELECT qa.id, qa.query_date AS 'Дата запроса', dc.name AS 'Направление', qa.research_theme AS 'Тема исследований', qa.head_name AS 'Руководитель', qa.contributors_number AS 'Участников', qa.amount_requested AS 'Сумма' FROM QueryArchive AS qa, DirectionClassifier AS dc WHERE qa.approved = 1 AND dc.id = qa.direction_id"
  results = client.query(query)
  keys = []
  results.each do |row|
    row.each {|key, val| keys << key}
    break
  end
  (nav = Array.new(5, ""))[1] =  "active"
  haml :index, :locals => {:title => "Запросы", :header => "Запросы", :stats => stats(client), :nav => nav, :keys => keys, :results => results}
end

get '/queries' do
  query = "SELECT qa.id, qa.query_date AS 'Дата запроса', DirectionClassifier.name AS 'Направление', qa.research_theme AS 'Тема исследований', qa.head_name AS 'Руководитель', qa.contributors_number AS 'Участников', qa.amount_requested AS 'Сумма', qa.approved AS 'Принят?' FROM QueryArchive AS qa, DirectionClassifier WHERE DirectionClassifier.id = qa.direction_id AND qa.approved != 1"
  results = client.query(query)
  keys = []
  results.each do |row|
    row.each {|key, val| keys << key}
    break
  end
  (nav = Array.new(5, ""))[4] =  "active"
  haml :queries, :locals => {:title => "Все запросы", :header => "Все запросы", :stats => stats(client), :nav => nav, :keys => keys, :results => results}
end

get '/grants' do
  query = "SELECT  ga.approved_date AS 'Дата выдачи', DirectionClassifier.name AS 'Направление', ga.research_theme AS 'Тема исследований', ga.head_name AS 'Руководитель', ga.contributors_number AS 'Участников', ga.amount_requested AS 'Запрошено', ga.amount_received AS 'Выдано' FROM GrantArchive AS ga, DirectionClassifier WHERE DirectionClassifier.id = ga.direction_id"
  results = client.query(query)
  success = []
  client.query('SELECT success FROM GrantResults').each do |row|
    success << row['success']
  end
  keys = []
  results.each do |row|
    row.each {|key, val| keys << key}
    break
  end
  (nav = Array.new(5, ""))[3] =  "active"
  haml :grants, :locals => {:title => "Гранты", :header => "Гранты", :stats => stats(client), :nav => nav, :keys => keys, :results => results, :success => success}
end

get '/new_query' do
  query = "SELECT * FROM DirectionClassifier"
  results = client.query(query)
  directions = []
  results.each do |row|
    directions << row["name"]
  end
  (nav = Array.new(5, ""))[0] = "active"
  haml :new, :locals => {:title => "Новый запрос", :header => "Новый запрос", :stats => stats(client), :nav => nav, :directions => directions}
end

post '/new_query_handler' do
  
  get_direction_id = "SELECT id FROM DirectionClassifier WHERE name = "
  get_black_list = "SELECT GrantArchive.head_name FROM GrantArchive, GrantResults WHERE GrantArchive.id = GrantResults.grant_id  AND (GrantResults.success = 0 OR GrantResults.success IS NULL)" # IN (SELECT grant_id FROM GrantResults WHERE success = 0)"
  get_deadline = "SELECT deadline FROM BudgetAndDeadline WHERE id = 1"
  
  direction_id = 0

  client.query(get_direction_id << "'#{params[:direction_name]}'").each do |row|
    direction_id = row["id"]
    break
  end

  insert_new_query = <<term 
    INSERT INTO QueryArchive (query_date, direction_id, research_theme, head_name, contributors_number, amount_requested, organisation, address, approved)
      VALUES
        (DATE(NOW()), #{direction_id}, '#{params[:research_theme]}', '#{params[:head_name]}', #{params[:contributors_number]}, #{params[:amount_requested]}, '#{params[:organisation]}', '#{params[:address]}', 
term

  deadline = 0
  black_list = []
  approved = 1

  client.query(get_deadline).each do |row|
    deadline = row["deadline"]
  end

  client.query(get_black_list).each do |row|
    black_list << row["head_name"]
  end

  client.query(get_black_list).each do |row|
    black_list << row["head_name"]
  end

  puts black_list.inspect

  approved = 3 if Date.today > deadline
  approved = 4 if black_list.include? params[:head_name]

  insert_new_query << "#{approved})"
  insert_new_query.gsub!(/\n/," ") 

  client.query(insert_new_query)

  redirect to('/choose')

end

post '/reject' do
  update_query = "UPDATE QueryArchive SET approved = 5 WHERE id = #{params[:id]}"
  client.query(update_query)
  "1"
end

post '/approve' do
  sq = {} # submited_query
  client.query("SELECT * FROM QueryArchive WHERE id = #{params[:id]}").each do |row|
    sq = row
  end

  budget = remaining_budget = amount_requested = total_received = coeff = 0

  client.query("SELECT budget, remaining_budget FROM BudgetAndDeadline WHERE id = 1").each do |row|
    budget = row["budget"]
    remaining_budget = row["remaining_budget"]
  end

  client.query("SELECT amount_requested FROM QueryArchive WHERE id = #{params[:id]}").each do |row|
    amount_requested = row["amount_requested"]
  end

  if amount_requested > (budget / 10)
    return "0"
  end

  if remaining_budget >= amount_requested
    update_query = "UPDATE BudgetAndDeadline SET remaining_budget=remaining_budget-#{amount_requested} "
  else
    client.query("SELECT SUM(ga.amount_received) as total_received FROM GrantArchive AS ga, GrantResults AS gr WHERE gr.grant_id = ga.id AND gr.success IS NULL").each do |row|
      total_received = row["total_received"]
    end

    if total_received.nil?
      return '-1'
    end

    if total_received > amount_requested - remaining_budget
      coeff = (amount_requested - remaining_budget) / total_received
    else
      return '-1'
    end

    client.query("UPDATE BudgetAndDeadline SET remaining_budget=0")
    update_query = "UPDATE GrantArchive SET amount_received=amount_received-(amount_received*#{coeff}) "

  end

  client.query(update_query)
  client.query("UPDATE QueryArchive SET approved = 2 WHERE id = #{params[:id]}")

  insert_grant = "INSERT INTO GrantArchive (direction_id, approved_date, research_theme, head_name, contributors_number, amount_requested, amount_received) "
  insert_grant += "VALUES (#{sq['direction_id']}, DATE(NOW()), '#{sq['research_theme']}', '#{sq['head_name']}', #{sq['contributors_number']}, #{amount_requested}, #{amount_requested})"

  client.query(insert_grant)

  result = "INSERT INTO `GrantResults` (grant_id, success) VALUES ((SELECT id from `GrantArchive` WHERE head_name = '#{sq['head_name']}'), NULL)"
  client.query(result)

  return "1"
end

get '/generate' do
  all = 100000
  DB.generate client, {:DirectionClassifier => 3 * all / 2, :Reasons => all, :GrantArchive => all, :QueryArchive => all / 2, :GrantResults => all / 2, :BudgetAndDeadline => 1}
  redirect to('/queries')
end

def handy_generate(client, all)
  DB.generate client, {:DirectionClassifier => all, :Reasons => 2 * all / 3, :GrantArchive => 2 * all / 3, :QueryArchive => all / 3, :GrantResults => all / 3, :BudgetAndDeadline => 1}
end

get '/report' do
  rejected = "SELECT query_date AS 'Дата запроса', DirectionClassifier.name AS 'Направление', research_theme AS 'Тема исследований', head_name AS 'Руководитель', contributors_number AS 'Участников', organisation AS 'Организация', address AS 'Адрес', Reasons.message AS 'Причина' FROM QueryArchive, DirectionClassifier, Reasons WHERE DirectionClassifier.id = QueryArchive.direction_id AND Reasons.id = QueryArchive.approved AND approved > 2"
  approved = "SELECT query_date AS 'Дата запроса', DirectionClassifier.name AS 'Направление', research_theme AS 'Тема исследований', head_name AS 'Руководитель', contributors_number AS 'Участников', organisation AS 'Организация', address AS 'Адрес', amount_requested AS 'Запрошено' FROM QueryArchive, DirectionClassifier WHERE DirectionClassifier.id = QueryArchive.direction_id AND approved = 2"
  results = client.query(approved)
  keys = []
  results.each do |row|
    row.each {|key, val| keys << key}
    break
  end
  bad = client.query(rejected)
  bad_keys = []
  bad.each do |row|
    row.each {|key, val| bad_keys << key unless key == "Причина"}
    break
  end
  sorted = {}
  bad.each do |row|
    puts 1
    reason = row["Причина"]
    row.delete("Причина")
    puts sorted[reason]
    sorted[reason] = sorted[reason].to_a + [row]
    puts sorted[reason]
  end
  puts sorted.inspect
  (nav = Array.new(5, ""))[2] =  "active"
  haml :report, :locals => {:title => "Отчёт", :header => "Полный отчёт", :stats => stats(client), :nav => nav, :keys => keys, :bad_keys => bad_keys, :results => results, :sorted => sorted}
end

post '/mail' do
  approved = 0
  head_name = ""
  client.query("SELECT QueryArchive.head_name, QueryArchive.approved FROM QueryArchive WHERE QueryArchive.id = #{params[:id]}").each do |row|
    approved = row['approved']
    head_name = row['head_name']
  end

  if approved == 2
    success = "SELECT  GrantArchive.amount_received FROM GrantArchive, GrantResults, QueryArchive WHERE GrantArchive.id = GrantResults.grant_id AND QueryArchive.head_name = '#{head_name}'"
    client.query(success).each do |row|
      return "Уважаемый #{head_name}!\nВаша заявка была принята и вам было выделено #{row['amount_received'].to_s('F')} рублей."
    end
  else
    failure = "SELECT Reasons.message FROM Reasons, GrantArchive WHERE Reasons.id = #{approved}"
    client.query(failure).each do |row|
      if approved != 4
        return "Уважаемый #{head_name}!\nВаша заявка была отклонена. Причина:\n #{row['message']} ."
      else
        year = 0
        client.query("SELECT GrantArchive.approved_date FROM GrantArchive, GrantResults WHERE GrantArchive.head_name = '#{head_name}' AND GrantResults.success = 0 AND GrantArchive.id = GrantResults.grant_id").each do |rw|
          year = rw['approved_date']
        end
        if year != 0
          return "Уважаемый #{head_name}!\nВаша заявка была отклонена. Причина:\n Грант не был выполнен в #{year} году."
        else
          return "Уважаемый #{head_name}!\nВаша заявка была отклонена. Причина:\n Вы уже получили грант в этом году."
        end
      end
    end
  end
end

get '/tests' do
  queries = {
    'ADD' => "INSERT INTO GrantArchive (direction_id, approved_date, research_theme, head_name, contributors_number, amount_requested, amount_received) VALUES (1, DATE(NOW()), 'ТЕСТ', 'ТЕСТ', 5, 5, 5)",
    'FIND KEY' => "SELECT * FROM GrantArchive WHERE id = 2",
    'FIND STRING' => "SELECT * FROM GrantArchive WHERE head_name = 'ТЕСТ' ",
    'FIND MASK' => "SELECT * FROM GrantArchive WHERE head_name LIKE 'F_%' ",
    'DELETE' => "DELETE FROM GrantArchive WHERE head_name = 'ТЕСТ' ",
    'DELETE MASK' => "DELETE FROM GrantArchive WHERE head_name LIKE 'R%' ",
    'Сжатие' => "OPTIMIZE TABLE GrantArchive"
  }
  haml :tests, :locals => {:title => "Тесты", :header => "Тесты", :stats => stats(client),  :nav => (a = Array.new(5, "")), :queries => queries}
end

post '/test' do
  query = params[:query]
  id = params[:id]
  time = 0
  100.times do |i|
    case id
    when "ADD"
      query[-12] = (i % 9 + 1).to_s
    when "FINDKEY"
      query[-1] = (i % 9 + 1).to_s
    when "FINDSTRING"
      query[-2] = (i % 9 + 1).to_s
    when "FINDMASK"
      query[-3] = (i % 9 + 1).to_s
    when "DELETE"
      query[-2] = (i % 9 + 1).to_s
    end
    puts query
    time += Benchmark.realtime do 
      client.query(query)
    end
  end
  "Среднее время запроса: #{time / 100.0}"
end

not_found do
  "404 :("
end