<html>
<head>
    <title>Load events from Honeywell</title>
    <meta charset="utf-8">
</head>
<body>
      <form method="post">
      <input type="submit" name="Submit" value="Submit">
</body>
</html>

<?php
if (isset($_POST['Submit'])) {
$output = shell_exec('sudo /root/scripts/honeywell.sh');
echo "<pre>$output</pre>";
}
?>
