<html>
<head>
    <title>Create new space</title>
    <meta charset="utf-8">
</head>
<body>
      <form method="post">
      <label for="SpaceName">Type new space name: </label>
      <input type="text" id="SpaceName" name="SpaceName" size="30" value="00001111 - New Project Name">
      <br><br>
      <label for="Description">Project description:</label>
      <input type="text" id="Description" name="Description" size="30" value="Develop sw and hw">
      <br><br>
      <input type="submit" name="Submit" value="Submit">
      <br><br>
</body>
</html>

<?php
if (isset($_POST['Submit'])) {
$space  = $_POST['SpaceName'];
$desc  = $_POST['Description'];
echo "You want to create \"$space\" as a name for new Space.<br>";
echo "Your description is \"$desc \".<br>";
$output = shell_exec("sudo /root/spacecreate.sh \"$space\" \"$desc\"");
echo "<br>Output is:<pre>$output</pre><br>";
}
?>
