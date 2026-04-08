<?php
	$link = mysql_connect('<DB_SOCKET>', '<DB_USER>', '<DB_PASSWORD>');
	if (!$link) { die ('Connection error: ' . mysql_error()); }

	$db_selected = mysql_select_db('visit', $link);
	if (!$db_selected) { die ('Database error: ' . mysql_error()); }

if (isset($_POST['Confirm'])) {
$date1  = $_POST['from'];
$date2  = $_POST['to']; }
else if (isset($_POST['csv'])) {
$date1  = '2014-01-01';
$date2  = date('Y-m-d'); }

$sql31 = "SELECT users.name, fe.first_event
FROM checkpoint
INNER JOIN (SELECT user_id, MIN(date) as first_event
FROM checkpoint WHERE direction = 'in'
AND user_id NOT IN (<EXCLUDED_USER_IDS>)
AND date BETWEEN '$date1' AND '$date2'
GROUP BY user_id, date(date)) fe
ON checkpoint.user_id = fe.user_id
AND checkpoint.date = fe.first_event
AND TIME(fe.first_event) BETWEEN '09:29:59' AND '09:44:59'
INNER JOIN users ON users.id = checkpoint.user_id
ORDER BY date, users.name";
$result31 = mysql_query($sql31);

$sql32 = "SELECT users.name, fe.first_event
FROM checkpoint
INNER JOIN (SELECT user_id, MIN(date) as first_event
FROM checkpoint WHERE direction = 'in'
AND user_id NOT IN (<EXCLUDED_USER_IDS>)
AND date BETWEEN '$date1' AND '$date2'
GROUP BY user_id, date(date)) fe
ON checkpoint.user_id = fe.user_id
AND checkpoint.date = fe.first_event
AND TIME(fe.first_event) BETWEEN '09:44:59' AND '09:59:59'
INNER JOIN users ON users.id = checkpoint.user_id
ORDER BY date, users.name";
$result32 = mysql_query($sql32);

$sql33 = "SELECT users.name, fe.first_event
FROM checkpoint
INNER JOIN (SELECT user_id, MIN(date) as first_event
FROM checkpoint WHERE direction = 'in'
AND user_id NOT IN (<EXCLUDED_USER_IDS>)
AND date BETWEEN '$date1' AND '$date2'
GROUP BY user_id, date(date)) fe
ON checkpoint.user_id = fe.user_id
AND checkpoint.date = fe.first_event
AND TIME(fe.first_event) BETWEEN '09:59:59' AND '10:29:59'
INNER JOIN users ON users.id = checkpoint.user_id
ORDER BY date, users.name";
$result33 = mysql_query($sql33);

$sql34 = "SELECT users.name, fe.first_event
FROM checkpoint
INNER JOIN (SELECT user_id, MIN(date) as first_event
FROM checkpoint WHERE direction = 'in'
AND user_id NOT IN (<EXCLUDED_USER_IDS>)
AND date BETWEEN '$date1' AND '$date2'
GROUP BY user_id, date(date)) fe
ON checkpoint.user_id = fe.user_id
AND checkpoint.date = fe.first_event
AND TIME(fe.first_event) BETWEEN '10:29:59' AND '17:59:59'
INNER JOIN users ON users.id = checkpoint.user_id
ORDER BY date, users.name";
$result34 = mysql_query($sql34);

$index = 0;
$ar = array();
$ar[$index] = array('name' => 'User', 'date' => '9-30 till 9-45' );
$index++;

while ($row31 = mysql_fetch_assoc($result31)) {
$ar[$index] = array('name' => $row31['name'], 'date' => $row31['first_event']);
$index++; }

$ar[$index] = array('name' => 'User', 'date' => '9-45 till 10-00' );
$index++;
while ($row32 = mysql_fetch_assoc($result32)) {
$ar[$index] = array('name' => $row32['name'], 'date' => $row32['first_event']);
$index++; }

$ar[$index] = array('name' => 'User', 'date' => '10-00 till 10-30' );
$index++;
while ($row33 = mysql_fetch_assoc($result33)) {
$ar[$index] = array('name' => $row33['name'], 'date' => $row33['first_event']);
$index++; }

$ar[$index] = array('name' => 'User', 'date' => '10-30 till 18-00' );
$index++;
while ($row34 = mysql_fetch_assoc($result34)) {
$ar[$index] = array('name' => $row34['name'], 'date' => $row34['first_event']);
$index++; }

function csv_download($ar) {
header('Content-Type: text/csv');
header('Content-Disposition: attachement; filename="export.csv"');
$fp = fopen('php://output', 'w');
foreach ($ar as $line) {
    fputcsv($fp, $line); }
}
csv_download($ar);

?>
