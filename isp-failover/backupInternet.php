<html>
<head>
    <title>Utility to monitor Internet</title>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="10,backupInternet.php">
</head>
<body>
      <p><b>Use Start if there is no Internet in Office1.<br>
      Use Stop if <a href=https://www.whatismyip.com/ target=_blank>external IP</a> is <PROVIDER1_SRC_IP></b></p>
      <p>Page refresh time is 10 seconds.</p>
      <form method="get">
      <input type="submit" name="Submit1" value="Start">
      </form>
      <form method="get">
      <input type="submit" name="Submit2" value="Stop">
      </form>
</body>
</html>

<?php

error_reporting(E_ALL);
ini_set('display_errors', 1);

$output = shell_exec('ssh -i /home/<USER>/.ssh/id_rsa root@<GATEWAY_IP> -p <SSH_PORT> "/home/wrapper.sh check"');
echo "<pre>$output</pre>";

if (isset($_GET['Submit1'])) {

echo "Starting..";

$output = shell_exec('ssh -i /home/<USER>/.ssh/id_rsa root@<GATEWAY_IP> -p <SSH_PORT> "/home/wrapper.sh start"');
echo "<pre>$output</pre>";

}

if (isset($_GET['Submit2'])) {

echo "Stopping..<br>";

$output = shell_exec('ssh -i /home/<USER>/.ssh/id_rsa root@<GATEWAY_IP> -p <SSH_PORT> "/home/wrapper.sh stop"');
echo "<pre>$output</pre>";

}

?>
