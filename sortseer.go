package main

import (
	"errors"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/emersion/go-message/mail"
	"github.com/emersion/go-smtp"

	// Support decoding all charsets
	// https://github.com/emersion/go-message/issues/148
	_ "github.com/emersion/go-message/charset"
)

var errError = errors.New("error")

// [^\s"] breaks on both whitespace and quote, ensuring it works for both plaintext and HTML
var re = regexp.MustCompile(`https://api\.dr\.dk/login/interactions/email/confirmation[^\s"]+`)

type Backend struct{}

func (bkd *Backend) NewSession(c *smtp.Conn) (smtp.Session, error) {
	return &Session{}, nil
}

type Session struct{}

func (s *Session) Mail(from string, opts *smtp.MailOptions) error {
	// TODO: ever heard of DMARC?
	if !strings.HasSuffix(from, "dr.dk") {
		return errError
	}
	return nil
}

func (s *Session) Rcpt(to string, opts *smtp.RcptOptions) error {
	if !strings.HasSuffix(to, "@sortseer.dk") {
		return errError
	}
	log.Println("RCPT:", to)
	return nil
}

func (s *Session) Data(r io.Reader) error {
	// https://godocs.io/github.com/emersion/go-message/mail#example-Reader
	// Create a new mail reader
	reader, err := mail.CreateReader(r)
	if err != nil {
		log.Fatal(err)
	}
	// Read each mail part
	for {
		part, err := reader.NextPart()
		if err != nil {
			if err == io.EOF {
				break
			}
			log.Fatal(err)
		}
		// Skip e.g. attachments
		_, isInline := part.Header.(*mail.InlineHeader)
		if !isInline {
			continue
		}
		// Read part body
		partBody, err := io.ReadAll(part.Body)
		if err != nil {
			log.Fatal(err)
		}
		// Find confirmation link
		match := re.Find(partBody)
		if match == nil {
			continue
		}
		link := string(match)
		log.Println(link)
		// Open link
		response, err := http.Get(link)
		if err != nil {
			log.Fatal(err)
		}
		// Check response
		responseBody, err := io.ReadAll(response.Body)
		response.Body.Close()
		log.Println(response.StatusCode)
		if response.StatusCode != 200 {
			log.Println(string(responseBody))
		}
		if err != nil {
			log.Fatal(err)
		}
		break
	}
	return nil
}

func (s *Session) Reset() {}

func (s *Session) Logout() error {
	return nil
}

func main() {
	// https://pkg.go.dev/github.com/emersion/go-smtp#example-Server
	backend := &Backend{}

	server := smtp.NewServer(backend)
	server.Addr = "0.0.0.0:25"
	server.Domain = "sortseer.dk"
	server.WriteTimeout = 5 * time.Second
	server.ReadTimeout = 5 * time.Second
	server.MaxMessageBytes = 1024 * 1024
	server.MaxRecipients = 5
	server.AllowInsecureAuth = true

	log.Println("Listening on", server.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
