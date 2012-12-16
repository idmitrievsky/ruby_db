# <center>Отчёт по базам данных</center>   

##Задание	Российский фонд фундаментальных исследований (РФФИ) на каждый год имеет бюджет для распределения между исследовательскими группами. Справочники: классификатор направлений исследования (номер, наименование) Имеется архив выделенных и невыделенных ранее грантов (направление по классификатору, тема исследований, ФИО руководителя, кол-во участников, запрошенная сумма, полученная сумма) и итогов работ по этим грантам (успех/неуспех). 	Запрос на грант: дата запроса, направление иссл. по классификатору, тема исследований, ФИО руководителя, кол-во участников запрашиваемая сумма, организация, адрес. Все гранты даются сроком на один год. Существует deadline для подачи заявок. Заявки, датированные позже не рассматриваются, но информация о них остаётся. Человек не может быть руководителем более чем одного гранта. Деньги выделяются так: пока есть деньги – выделяем столько, сколько просят, но не более чем 10% от общего бюджета. Когда деньги закончились, а достойные заявки ещё есть – надо втиснуть заявку в бюджет, пропорционально уменьшив суммы для всех.
	
Требуется:	* Поддержка приёма заявок (в том числе отсев по deadline)
* Поддержка рассмотрения заявок (достойно/недостойно + если уже был выделен грант этому человеку, а он его не выполнил, то отказ)Поддержка «втискивания» заявок в бюджет* Поддержка генерации писем по итогам полного рассмотрения («...заявка принята и вам выделено...», «...заявка отклонена, потому что поздно прислали...», «...заявка отклонена, потому что ваша тема – полное фуфло...»,  «...заявка не принята, потому что в таком-то году вы ничего не сделали по такой-то теме...»)* Поддержка отчётов: полный раскрытый перечень удовлетворённых заявок, список неудовлетворённых заявок с группировкой по причинам
## Схема реализации БД
![image](/Users/ivan/Desktop/BD.png)

### Таблица BudgetAndDeadline
![image](/Users/ivan/Desktop/BudDead.png)
  
### Таблица DirectionClassifier
![image](/Users/ivan/Desktop/DirCla.png)

### Таблица GrantArchive
![image](/Users/ivan/Desktop/GraArc.png)

	direction_id – внешний ключ для DirectionClassifier (id)
	
### Таблица GrantResults
![image](/Users/ivan/Desktop/GraRes.png)

	grant_id – внешний ключ для GrantArchive (id)

### Таблица QueryArchive
![image](/Users/ivan/Desktop/QueArc.png)
	
	direction_id – внешний ключ для DirectionClassifier (id)	approved – внешний ключ для Reasons (id)
### Таблица Reasons
![image](/Users/ivan/Desktop/Rea.png)

## Запросы

* **Запрос статистики:**  
	```
	SELECT budget, remaining_budget, deadline FROM BudgetAndDeadline WHERE id = 1
	```
* **Запрос на получение рассматриваемых заявок:**  

	```
SELECT qa.id, qa.query_date, dc.name, qa.research_theme, qa.head_name, qa.contributors_number, qa.amount_requested, qa.approved
FROM QueryArchive AS qa, DirectionClassifier as dc
WHERE dc.id = qa.direction_id AND qa.approved != 1
	```
* **Запрос на получение списка грантов:**  

	```
SELECT  ga.approved_date, dc.name, ga.research_theme, ga.head_name, ga.contributors_number, ga.amount_requested, ga.amount_received
FROM GrantArchive AS ga, DirectionClassifier AS dc
WHERE dc.id = ga.direction_id
	```
* **Обработка нового запроса на грант:**
	* **Получение ID направления:**  
		`SELECT id FROM DirectionClassifier WHERE name = :name`
	* **Получение чёрного списка:**  
	
		```
SELECT ga.head_name
FROM GrantArchive AS ga, GrantResults AS gr 
WHERE ga.id = gr.grant_id  AND (gr.success = 0 OR gr.success IS NULL)
		```
	* **Получение дедлайна:**  
		`SELECT deadline FROM BudgetAndDeadline WHERE id = 1`	* **Добавление запроса на грант:**
		```
	INSERT INTO QueryArchive (query_date, direction_id, research_theme, head_name, 	contributors_number, amount_requested, organisation, address, approved) 
	VALUES
(DATE(NOW()), :direction_id, :research_theme, :head_name, :contributors_number, :amount_requested, :organisation, :address, :approved)
        ```
* **Запрос на отклонение запроса на грант:**  
	`UPDATE QueryArchive SET approved = 5 WHERE id = :id`
* **Обработка одобрения запроса на грант:**  
	* **Получение бюжетов:**  
	`SELECT budget, remaining_budget FROM BudgetAndDeadline WHERE id = 1`
	* **Получение требуемой суммы:**  
	`SELECT amount_requested FROM QueryArchive WHERE id = :id`
	* **Взятие денег из бюджета:**  
	`UPDATE BudgetAndDeadline SET remaining_budget=remaining_budget - :amount_requested`
	* **Получение уже розданных денег:**  
	
		```
	SELECT SUM(ga.amount_received) as total_received
	FROM GrantArchive AS ga, GrantResults AS gr
	WHERE gr.grant_id = ga.id AND gr.success IS NULL
		```
	* **Обнуление бюджета:**  
	`UPDATE BudgetAndDeadline SET remaining_budget=0`
	* **Втискивание:**  
	`UPDATE GrantArchive SET amount_received=amount_received-(amount_received* :k) `
	* **Одобрение заявки:**  
	`UPDATE QueryArchive SET approved = 2 WHERE id = :id`
	* **Добавление гранта:**  
	
		```
	INSERT INTO GrantArchive (direction_id, approved_date, research_theme, head_name, contributors_number, amount_requested, amount_received)
	VALUES (:direction_id, DATE(NOW()), :research_theme, :head_name, :contributors_number, :amount_requested, :amount_requested)
		```
	* **Добавление пометки 'в процессе'**  
	
		```
	INSERT INTO GrantResults (grant_id, success)
	VALUES ((SELECT id from GrantArchive
	WHERE head_name = :head_name), NULL)
		```
* **Запрос на получение отклонённых заявок:**  

	```
	SELECT query_date, DirectionClassifier.name, research_theme, head_name, contributors_number, organisation, address, Reasons.message
	FROM QueryArchive, DirectionClassifier, Reasons
	WHERE DirectionClassifier.id = QueryArchive.direction_id AND Reasons.id = QueryArchive.approved AND approved > 2
	```
* **Запрос на получение принятых заявок:**  
	
	```
	SELECT query_date, DirectionClassifier.name, research_theme, head_name, contributors_number, organisation, address, amount_requested
	FROM QueryArchive, DirectionClassifier
	WHERE DirectionClassifier.id = QueryArchive.direction_id AND approved = 2
	```
* **Запрос на получение грантов в процессе с данным руководителем:**  

	```
	SELECT  GrantArchive.amount_received
	FROM GrantArchive, GrantResults, QueryArchive
	WHERE GrantArchive.id = GrantResults.grant_id AND GrantResults.success IS NULL AND QueryArchive.head_name = :head_name
	```
* **Запрос на получение дат провалившихся грантов с данным руководителем:**  
	
	```
	SELECT GrantArchive.approved_date
	FROM GrantArchive, GrantResults
	WHERE GrantArchive.head_name = :head_name AND GrantResults.success = 0 AND GrantArchive.id = GrantResults.grant_id
	```
	
## Тесты

---

    INSERT INTO GrantArchive (direction_id, approved_date, research_theme, head_name, contributors_number, amount_requested, amount_received)
    VALUES (1, DATE(NOW()), 'ТЕСТ', 'ТЕСТ', 5, 5, 5)
    
    SELECT * FROM GrantArchive
    WHERE id = 2
    
    SELECT * FROM GrantArchive WHERE head_name = 'ТЕСТ'
    
    SELECT * FROM GrantArchive WHERE head_name LIKE 'F%'
    
    DELETE FROM GrantArchive WHERE head_name = 'ТЕСТ'
   
    DELETE FROM GrantArchive WHERE head_name LIKE 'R%'
    
    OPTIMIZE TABLE GrantArchive
---

 Запрос    |   1000   |  10 000  |  100 000  |    C    |
:--------: | :------: | :------: | :-------: | :-----: |
   ADD     |0.00044804|0.00024015|  0.000571 | **O(1)**|   
 FIND KEY  |0.00016279|0.0001645 |  0.0001677| **O(log(2, n))**|
FIND STRING|0.00098861|0.0070647 | 0.0702311 | **O(n)**|
 FIND MASK |0.0009789 | 0.0076557|  0.0762837| **O(n)**|
  DELETE   |0.00098549|0.00829897|  0.0833506| **O()**|
DELETE MASK|0.00114407 |0.0088568 | 0.0849359 | **O()**|
  Сжатие   |0.18377973|0.38232257|  2.6361792| **O()**|     
    
 ---
  
  **ADD.**
  Время добавления не зависит от количества записей.  
  **FIND KEY.**
  Для поиска используется бинарное дерево поиска.  
  **FIND STRING.** Нужно пройти по каждой строке.  
  **FIND MASK.** Нужно пройти по каждой строке.  
  **DELETE.** Поиск происходит за логарифмическое время ?, а время пометки строки – константа.  
  **DELETE MASK.** Поиск происходит за линейное время, а время пометки строки – константа.  
  **Сжатие.** Чем больше записей осталось в таблице, тем большее время занимает операция.
  
  