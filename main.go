package main

import (
	"log"
	"net/http"
)

func main() {
	http.Handle("/", http.FileServer(http.Dir("./dist")))
	log.Fatal(http.ListenAndServe(":3000", nil))
}
