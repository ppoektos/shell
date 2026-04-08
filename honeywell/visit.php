<html>
<head>
    <title>Visit database</title>
    <link rel="stylesheet" type="text/css" href="style.css">
    <meta charset="utf-8">
<link rel="stylesheet" href="//code.jquery.com/ui/1.11.0/themes/smoothness/jquery-ui.css">
<script src="//code.jquery.com/jquery-1.10.2.js"></script>
<script src="//code.jquery.com/ui/1.11.0/jquery-ui.js"></script>
<script>
$(function() {
$( "#from" ).datepicker({
defaultDate: "+1w",
changeMonth: true,
numberOfMonths: 1,
dateFormat: "yy-mm-dd",
onClose: function( selectedDate ) {
$( "#to" ).datepicker( "option", "minDate", selectedDate );
}
});
$( "#to" ).datepicker({
defaultDate: "+1w",
changeMonth: true,
numberOfMonths: 1,
dateFormat: "yy-mm-dd",
onClose: function( selectedDate ) {
$( "#from" ).datepicker( "option", "maxDate", selectedDate );
}
});
});
</script>
</head>
<body>
<?php
	$link = mysql_connect('<DB_SOCKET>', '<DB_USER>', '<DB_PASSWORD>');
	if (!$link) { die ('Connection error: ' . mysql_error()); }

	$db_selected = mysql_select_db('visit', $link);
	if (!$db_selected) { die ('Database error: ' . mysql_error()); }

	$sql = "SELECT users.name FROM users ORDER BY name";
	$sql1 = "SELECT users.name FROM users ORDER BY name";
	$result = mysql_query($sql);
	$result1 = mysql_query($sql1);

	if (!$result) {
	    $message  = 'Wrong query: ' . mysql_error() . "\n";
	    $message .= 'Query: ' . $sql;
	    die($message); }
?>
<table id='tb1'>
<tr>
  <th>Upload EventReport.csv</th>
  <th>Full user report</th>
  <th>Date report</th>
  <th>CSV export</th>
  <th>Date+User report</th>
</tr>
<tr>
  <td>
      <form action="visit.php" method="post"
      enctype="multipart/form-data">
      <label for="file">Select file:</label>
      <input type="file" name="file" id="file"><br>
      <input type="submit" name="Submit" value="Submit">
      </form>
  </td>
  <td>
      <form action="visit.php" method="POST">
	  <select name="userlist">
	    <?php while ($row = mysql_fetch_assoc($result)) { ?>
	      <option value="<?php echo $row['name'] ?>"><?php echo $row['name'] ?></option>
	    <?php } ?>
	  </select>
	<input type="submit" name="submit" value="submit" />
      </form>
  </td>
  <td>
      <form action="visit.php" method="POST">
	<label for="from">From</label>
	<input type="text" id="from" name="from" value="<?php echo ($_POST) ? $_POST['from']:'';?>">
	<label for="to">to</label>
	<input type="text" id="to" name="to" value="<?php echo ($_POST) ? $_POST['to']:'';?>">
	<input type="submit" name="Confirm" value="Confirm" />
      </form>
  </td>
  <td>
      <form action="visit1.php" method="POST">
	<label for="from">From</label>
	<input type="text" id="from" name="from" value="<?php echo ($_POST) ? $_POST['from']:'';?>">
	<label for="to">to</label>
	<input type="text" id="to" name="to" value="<?php echo ($_POST) ? $_POST['to']:'';?>">
	<input type="submit" name="Confirm" value="Confirm" />
	<input type="submit" name="csv" value="Full CSV" />
      </form>
  </td>
  <td>
      <form action="visit.php" method="POST">
	  <select name="userlist2">
	    <?php while ($row1 = mysql_fetch_assoc($result1)) { ?>
	      <option value="<?php echo $row1['name'] ?>"><?php echo $row1['name'] ?></option>
	    <?php } ?>
	  </select>
	    <br>
	<label for="date3">From: </label>
	  <input name="from2" id="date3" size="10" type="text" value="2014-07-01"/>
	<label for="date4">Till: </label>
	  <input name="till2" id="date4" size="10" type="text" value="2014-07-04"/>
	<input type="submit" name="confirm" value="confirm" />
      </form>
  </td>
</tr>
</table>
</body>
</html>

<?php
if (isset($_POST['submit'])) {
  $user = $_POST['userlist'];

$sql2 = "SELECT users.name, checkpoint.date, checkpoint.direction
FROM checkpoint
INNER JOIN users ON users.id = checkpoint.user_id
WHERE users.name = '$user'";

$result2 = mysql_query($sql2);

while($row2 = mysql_fetch_assoc($result2)) {
  echo $row2['name'] . " " . $row2['date'] . " " . $row2['direction'];
  echo "<br>"; }
}

if (isset($_POST['Submit'])) {

if (file_exists("upload/" . $_FILES["file"]["name"])) {
  echo $_FILES["file"]["name"] . " already exists. ";
} else {
move_uploaded_file($_FILES["file"]["tmp_name"],
"upload/" . $_FILES["file"]["name"]);
echo "Stored in: " . "upload/" . $_FILES["file"]["name"];
shell_exec('./loadevents.sh');
}
}

$index = 0;
$ar = array();

if (isset($_POST['Confirm'])) {
$date1  = $_POST['from'];
$date2  = $_POST['to'];

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

echo "<table class='tb2', align='left'>
<tr>
<th>User</th>
<th>9-30 till 9-45</th>
</tr>";
while ($row31 = mysql_fetch_assoc($result31)) {
$ar[$index] = array('name' => $row31['name'], 'date' => $row31['first_event']);
$index++;
  echo "<tr>";
  echo "<td>" . $row31['name'] . "</td>";
  echo "<td>" . $row31['first_event'] . "</td>";
  echo "</tr>"; }
echo "</table>";

echo "<table class='tb2', align='left'>
<tr>
<th>User</th>
<th>9-45 till 10-00</th>
</tr>";
while ($row32 = mysql_fetch_assoc($result32)) {
$ar[$index] = array('name' => $row32['name'], 'date' => $row32['first_event']);
$index++;
  echo "<tr>";
  echo "<td>" . $row32['name'] . "</td>";
  echo "<td>" . $row32['first_event'] . "</td>";
  echo "</tr>"; }
echo "</table>";

echo "<table class='tb2', align='left'>
<tr>
<th>User</th>
<th>10-00 till 10-30</th>
</tr>";
while ($row33 = mysql_fetch_assoc($result33)) {
$ar[$index] = array('name' => $row33['name'], 'date' => $row33['first_event']);
$index++;
  echo "<tr>";
  echo "<td>" . $row33['name'] . "</td>";
  echo "<td>" . $row33['first_event'] . "</td>";
  echo "</tr>"; }
echo "</table>";

echo "<table class='tb2', align='left'>
<tr>
<th>User</th>
<th>10-30 till 18-00</th>
</tr>";
while ($row34 = mysql_fetch_assoc($result34)) {
$ar[$index] = array('name' => $row34['name'], 'date' => $row34['first_event']);
$index++;
  echo "<tr>";
  echo "<td>" . $row34['name'] . "</td>";
  echo "<td>" . $row34['first_event'] . "</td>";
  echo "</tr>"; }
echo "</table>";
}

if (isset($_POST['confirm'])) {
$user2 = $_POST['userlist2'];
$date3  = $_POST['from2'];
$date4  = $_POST['till2'];
$sql4 = "SELECT users.name, checkpoint.date, checkpoint.direction
FROM checkpoint
INNER JOIN users ON users.id = checkpoint.user_id
WHERE users.name = '$user2'
AND checkpoint.date BETWEEN '$date3' AND '$date4'";
$result4 = mysql_query($sql4);
while($row4 = mysql_fetch_assoc($result4)) {
  echo $row4['name'] . " " . $row4['date'] . " " . $row4['direction'];
  echo "<br>"; }
}

mysql_free_result($result);

mysql_close($link);
?>
