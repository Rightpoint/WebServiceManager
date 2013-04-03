<?php
	$data = [
		"postFields" => $_POST,
		"postData" => $_FILES,
	];

    echo json_encode($data);
?>