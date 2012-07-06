<?php

    /* PUT data comes in on the stdin stream */
    $putdata = fopen("php://input", "r");

    /* Read the data 1 KB at a time
       and echo it back */
    while ($data = fread($putdata, 1024))
    {
        echo $data;
    }

    /* Close the stream */
    fclose($putdata);
?>