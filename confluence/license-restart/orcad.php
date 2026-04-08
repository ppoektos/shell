<html>
<head>
    <title>Restart Orcad licensing server</title>
    <meta charset="utf-8">
</head>
<body>
      <p>You've to wait two minutes to see effect.<br>
      <b>And don't press Submit again until you see result!</b></p>
      <form method="post">
      <label>Restart <LICENSE_SERVER_1>:</label>
      <input type="submit" name="Submit1" value="Submit">
      </form>
      <form method="post">
      <label>Restart <LICENSE_SERVER_2>:</label>
      <input type="submit" name="Submit2" value="Submit">
      </form>
</body>
</html>

<?php
if (isset($_POST['Submit1'])) {
echo "Details are below:";
$output = shell_exec('sudo /root/scripts/resorcad.sh <LICENSE_SERVER_1>');
echo "<pre>$output</pre>";
}
if (isset($_POST['Submit2'])) {
echo "Details are below:";
$output = shell_exec('sudo /root/scripts/resorcad.sh <LICENSE_SERVER_2>');
echo "<pre>$output</pre>";
}
?>
