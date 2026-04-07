<html>
<head>
    <title>Lunch orders by week</title>
    <meta charset="utf-8">
</head>
<body>

<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

$Year = isset($_GET["year"]) ? $_GET["year"] : 'undefined';
$CurrentWeek = date('W');
$CurrentYear = date('Y');
$WeekMode = 7;

$conn = mysqli_connect("<DB_HOST>","<DB_USER>","<DB_PASSWORD>","lunchorder");

if (mysqli_connect_errno()) { echo "Failed to connect to MySQL: " . mysqli_connect_error(); }

if ( $Year != $CurrentYear) { $CurrentWeek = 53; }

if ( $Year == 2020 ) { $WeekMode = 3; }
if ( $Year == 2019 ) { $WeekMode = 3; }

for ($i = 1; $i <= $CurrentWeek; $i++) {

    $sql = "SELECT order_date, user, name FROM orders, `groups`
            WHERE week(order_date,3) = '$i'
            AND year(order_date) = '$Year'
            AND `groups`.id = orders.group_id
            ORDER BY order_date;";

    $result1 = mysqli_query($conn, $sql);

    $Company1AndGuests = "SELECT count(orders.user) as count
                        FROM orders, `groups`
                        WHERE orders.group_id = `groups`.id
                        AND `groups`.name IN ('company1', 'guest_company1')
                        AND orders.user NOT LIKE '%Company4%'
                        AND week(order_date,$WeekMode) = $i
                        AND year(order_date) = $Year;";

    $result2 = mysqli_query($conn, $Company1AndGuests);

    $Company2AndGuests = "SELECT count(orders.user) as count
                        FROM orders, `groups`
                        WHERE orders.group_id = `groups`.id
                        AND `groups`.name IN ('company2', 'guest_company2')
                        AND week(order_date,$WeekMode) = '$i'
                        AND year(order_date) = '$Year';";

    $result3 = mysqli_query($conn, $Company2AndGuests);

    $Company3 = "SELECT count(orders.user) as count
               FROM orders, `groups`
               WHERE orders.group_id = `groups`.id
               AND `groups`.name = 'company3'
               AND week(order_date,$WeekMode) = '$i'
               AND year(order_date) = '$Year';";

    $result4 = mysqli_query($conn, $Company3);

    $Company4 = "SELECT count(orders.user) as count
           FROM orders, `groups`
           WHERE orders.group_id = `groups`.id
           AND orders.user LIKE '%Company4%'
           AND week(order_date,$WeekMode) = '$i'
           AND year(order_date) = '$Year';";

    $result5 = mysqli_query($conn, $Company4);

    $Total = "SELECT count(orders.user) as count
              FROM orders
              WHERE week(order_date,$WeekMode) = '$i'
              AND year(order_date) = '$Year';";

    $result6 = mysqli_query($conn, $Total);

    while ($row6 = mysqli_fetch_assoc($result6)) { echo "<b>Year $Year, week $i, total orders: " . $row6['count'] . ".</b><br>"; }

    while ($row2 = mysqli_fetch_assoc($result2)) { $C1 = $row2['count']; }
    while ($row3 = mysqli_fetch_assoc($result3)) { $C2 = $row3['count']; }
    while ($row4 = mysqli_fetch_assoc($result4)) { $C3 = $row4['count']; }
    while ($row5 = mysqli_fetch_assoc($result5)) { $C4 = $row5['count']; }

    echo "<hr>";
    echo "<p style=\"color:#99b2ee;\"><b>Company1AndGuests: " . $C1 . "</b>, <span style=\"color:#dc9ee0\"><b>Company2AndGuests: " . $C2 . "</b>,</span> <span style=\"color:#9def90\"><b>Company3: " . $C3 . "</b>,</span> <span style=\"color:#fa716d\"><b>Company4: " . $C4 . "</b>.</span></p>";
    echo "<hr>";
?>

<table border="1px solid black" cellpadding="3" style="border-collapse: collapse; text-align: center;">
  <th>Lunch date</th>
  <th>Person</th>
  <th>Group</th>
</tr>

<?php
    while ($row1 = mysqli_fetch_assoc($result1)) {

        if ($row1['name'] == 'company1') { $status_colors = "#99b2ee"; }
        elseif ($row1['user'] == 'Company4_Person') { $status_colors = "#fa716d"; }
        elseif ($row1['name'] == 'guest_company1') { $status_colors = "#7187ec"; }
        elseif ($row1['name'] == 'company2') { $status_colors = "#dc9ee0"; }
        elseif ($row1['name'] == 'guest_company2') { $status_colors = "#db70e2"; }
        else { $status_colors = "#9def90"; }

        echo "<tr style=\"background-color: " . $status_colors . "\">";
        echo "<td>" . $row1['order_date'] . "</td><td>" . $row1['user'] . "</td><td>" . $row1['name'] . "</td>";
        echo "</tr>";
    }
?>

</table>

<?php
echo "<hr>";
}
mysqli_close($conn);
?>

</body>
</html>
