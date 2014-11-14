#Define the local folder, network mapped drive, or file share to searh and the name of the output CSV to be attached.
$searchDirectory = "C:\Users"
$attachmentFile = "CryptoWall Decrypt Files - " + (Get-Date).ToLongDateString() + ".csv"

#Perform recursive search for suspected decrypt instruction files in subfolders that have a creation date between now and this time yesterday inclusive.
$today=[DateTime]::Today
$yesterday=$today.AddDays(-1)
$results = Get-ChildItem –Path $searchDirectory -Recurse -Force -Include decrypt_instruction*, install_tor* | Where { $_.LastWriteTime -le $today -and $_.LastWriteTime -ge $yesterday } | Sort-Object | Get-Unique

#If nothing was found, exit script.
if ($results.Count -eq 0)
{
    Write-Host "Nothing found; exit script."
    return
}

#Define email parameters
$smtpServer = "smtp.example.com"
$emailFrom = "no-reply@example.com"
$emailTo = "admins@example.com"
$hostName=hostname
$subject = "Found CryptoWall From $hostName"
$body = "This is a notification email from $hostName sent through $smtpServer.  CryptoWall instruction files have been found!  A possible infection may have occured from the file owner and these directories may have been encrypted.  Please see attached file for more info."

#For each file that was found, store file properties in a list as a custom object.
$decryptFilesList = @()
foreach ($r in $results)
{
    #Get the owner of the file.
    $owner = $r | Get-Acl | Select Owner
    
    #Define custom object, properties, and set property values.
    $decryptFile = New-Object PSCustomObject
    $decryptFile | Add-Member -MemberType NoteProperty -Name Owner -Value $owner.Owner
    $decryptFile | Add-Member -MemberType NoteProperty -Name CreationDate -Value $r.CreationTime
    $decryptFile | Add-Member -MemberType NoteProperty -Name ModifiedDate -Value $r.LastWriteTime
    $decryptFile | Add-Member -MemberType NoteProperty -Name Filepath -Value $r.FullName 

    #Add custom object to list.
    $decryptFilesList += $decryptFile
}

#Export the custom object list to a CSV file to attach to the alert email notification.
$decryptFilesList | Export-Csv $attachmentFile -NoTypeInformation

#Create email attachment and message objects.
$attachment=new-object Net.Mail.Attachment($attachmentFile)
$message=new-object Net.Mail.MailMessage
$message.from=$emailFrom
$message.to.add($emailTo)
$message.subject=$subject
$message.body=$body
$message.attachments.add($attachment)

#Create smtp object and send.
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($message)
