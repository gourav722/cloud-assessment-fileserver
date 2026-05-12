package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	fileserver "github.com/yosssi/go-fileserver"
)

func main() {

	dataDir := os.Getenv("DATA_DIR")

	if dataDir == "" {
		dataDir = "./data"
	}

	port := os.Getenv("PORT")

	if port == "" {
		port = "8081"
	}

	fs := fileserver.New(fileserver.Options{})

	http.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		path := dataDir + r.URL.Path

		if _, err := os.Stat(path); os.IsNotExist(err) {

			w.Header().Set("Content-Type", "application/json")

			w.WriteHeader(http.StatusNotFound)

			json.NewEncoder(w).Encode(map[string]string{
				"error": "file not found",
			})

			return
		}

		fs.Serve(http.Dir(dataDir)).ServeHTTP(w, r)
	}))

	log.Printf("starting server on :%s", port)

	log.Fatal(http.ListenAndServe(":"+port, nil))
}