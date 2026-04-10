<html>
<head>
    <title>Expenses report</title>
    <meta charset="utf-8">
</head>

<body>

<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
$year = isset($_GET["year"]) ? $_GET["year"] : 'undefined';

$conn = mysqli_connect("localhost","<DB_USER>","<DB_PASSWORD>","expenses");

if (mysqli_connect_errno())
  { echo "Failed to connect to MySQL: " . mysqli_connect_error(); }

$sql = "SELECT month(expense_date) as month, office1_cash, office1_exp,
        office1_bal, office2_cash, office2_exp, office2_bal
        FROM main
        WHERE year(expense_date) = '$year';";

$result = mysqli_query($conn, $sql);

if (!$result) {
    $message  = 'Wrong query: ' . mysql_error() . "\n";
    $message .= 'Query: ' . $sql;
    die($message); }

?>

<table class="exp">
<tr>
  <th></th>
  <th colspan="3" bgcolor="#82CAFF">office1</th>
  <th colspan="3" bgcolor="#E0FFFF">office2</th>
</tr>
<tr>
  <th>Month</th>
  <th bgcolor="#82CAFF">Cash</th>
  <th bgcolor="#82CAFF">Expenses</th>
  <th bgcolor="#82CAFF">Balance</th>
  <th bgcolor="#E0FFFF">Cash</th>
  <th bgcolor="#E0FFFF">Expenses</th>
  <th bgcolor="#E0FFFF">Balance</th>
</tr>

<?php
while ($row = mysqli_fetch_assoc($result)) {

$m = $row['month'];

$sql1 = "SELECT description, money
        FROM exp
        WHERE branch = 'office1'
        AND month(date) = '$m'
        AND year(date) = '$year'
        AND ExpType = 'Deposit';";

$result1 = mysqli_query($conn, $sql1);

$sql2 = "SELECT description, money
        FROM exp
        WHERE branch = 'office2'
        AND month(date) = '$m'
        AND year(date) = '$year'
        AND ExpType = 'Deposit';";

$result2 = mysqli_query($conn, $sql2);

  echo "<tr>";
  echo "<td>" . $m . "</td>";
  echo "<td style=\"background-color:#82CAFF\"><b>" . $row['office1_cash'] . "</b><br>";
  while ($row1 = mysqli_fetch_assoc($result1))
    { echo $row1['description'] . "-" . $row1['money'] . " "; }
  echo "</td>";
  echo "<td style=\"background-color:#82CAFF\"><b>" . $row['office1_exp'] . "</b></td>";
  echo "<td style=\"background-color:#82CAFF\"><b>" . $row['office1_bal'] . "</b></td>";
  echo "<td style=\"background-color:#E0FFFF\"><b>" . $row['office2_cash'] . "</b><br>";
  while ($row2 = mysqli_fetch_assoc($result2))
    { echo $row2['description'] . "-" . $row2['money'] . " "; }
  echo "</td>";
  echo "<td style=\"background-color:#E0FFFF\"><b>" . $row['office2_exp'] . "</b></td>";
  echo "<td style=\"background-color:#E0FFFF\"><b>" . $row['office2_bal'] . "</b></td>";
  echo "</tr>";
  }
?>

</table>

<?php
  $offices = array("office1", "office2");
  $types = array("Administrative", "Office", "Project", "Lab", "Travel", "Trial_salary");

  foreach ($offices as $office) {
    echo "<h2 style=\"cursor: default;\" align=\"center\">Monthly expenses in " . strtoupper("$office") . "</h2>";

    for ($i = 1; $i <= 12; $i++) {
?>

<div class="toggleWrapper">
<span class="clicker" style="cursor: pointer;"><?php echo date('F', mktime(0, 0, 0, $i, 1));?></span><br>
<div class="toggleInner" style="cursor: default;">

<?php
        foreach ($types as $type) {

            $sql3 = "SELECT sum(money) as M
                    FROM exp
                    WHERE branch = '$office'
                    AND month(date) = '$i'
                    AND year(date) = '$year'
                    AND ExpType = '$type';";

            $result3 = mysqli_query($conn, $sql3);

            while ($row3 = mysqli_fetch_assoc($result3))
            { echo "$type: " . $row3['M'] . "<br>"; }

            $sql4 = "SELECT date as Date, description as Description, resp as Responsible, money as Money
                    FROM exp
                    WHERE branch = '$office'
                    AND month(date) = '$i'
                    AND year(date) = '$year'
                    AND ExpType = '$type'
                    ORDER BY date;";

            $result4 = mysqli_query($conn, $sql4);

                echo "<table class=\"exp\">";
                echo "<tr>";
                    echo "<th>Date</th>";
                    echo "<th>Description</th>";
                    echo "<th>Responsible</th>";
                    echo "<th>Money</th>";
                echo "</tr>";

            while ($row4 = mysqli_fetch_assoc($result4)) {
                    echo "<tr>";
                    echo "<td>" . $row4['Date'] . "</td>";
                    echo "<td>" . $row4['Description'] . "</td>";
                    echo "<td>" . $row4['Responsible'] . "</td>";
                    echo "<td>" . $row4['Money'] . "</td>";
                    echo "</tr>";
            }

        echo "</table>";

        }

        echo "Sum per projects:<br>";
        $sql5 = "SELECT ProjectNumber as Project , sum(money) as Money
                FROM exp
                WHERE ProjectSpecified = 1
                AND branch = '$office'
                AND month( date ) = '$i'
                AND year( date ) = '$year'
                GROUP BY ProjectNumber";

        $result5 = mysqli_query($conn, $sql5);

        echo "<table class=\"exp\">";
        echo "<tr>";
            echo "<th>Project</th>";
            echo "<th>Money</th>";
        echo "</tr>";

        while ($row5 = mysqli_fetch_assoc($result5)) {
                echo "<tr>";
                echo "<td>" . $row5['Project'] . "</td>";
                echo "<td>" . $row5['Money'] . "</td>";
                echo "</tr>";
            }
        echo "</table>";
?>

</div></div>

<?php
  }
}
mysqli_close($conn);
?>

</body>
</html>
