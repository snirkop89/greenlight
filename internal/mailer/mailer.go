package mailer

import (
	"bytes"
	"embed"
	"html/template"
	"log"
	"time"

	"github.com/go-mail/mail/v2"
)

//go:embed "templates"
var templateFS embed.FS

type Mailer struct {
	// dailer used to connect to a SMTP server
	dialer *mail.Dialer
	// The address you want the email's "from" to be
	sender string
}

func New(host string, port int, username, password, sender string) Mailer {
	dailer := mail.NewDialer(host, port, username, password)
	dailer.Timeout = 10 * time.Second

	return Mailer{
		dialer: dailer,
		sender: sender,
	}
}

func (m Mailer) Send(recipient, templateFile string, data any) error {
	tmpl, err := template.New("email").ParseFS(templateFS, "templates/"+templateFile)
	if err != nil {
		return err
	}

	subject := new(bytes.Buffer)
	err = tmpl.ExecuteTemplate(subject, "subject", data)
	if err != nil {
		return err
	}

	plainBody := new(bytes.Buffer)
	err = tmpl.ExecuteTemplate(plainBody, "plainBody", data)
	if err != nil {
		return err
	}
	log.Println(plainBody.String())

	htmlBody := new(bytes.Buffer)
	err = tmpl.ExecuteTemplate(htmlBody, "htmlBody", data)
	if err != nil {
		return err
	}

	// build the mail message
	msg := mail.NewMessage()
	msg.SetHeader("To", recipient)
	msg.SetHeader("From", m.sender)
	msg.SetHeader("Subject", subject.String())
	msg.SetBody("text/plain", plainBody.String())
	msg.AddAlternative("text/html", htmlBody.String())

	err = m.dialer.DialAndSend(msg)
	if err != nil {
		return err
	}

	return nil
}
