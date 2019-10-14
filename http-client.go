package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
)

func main() {
	url := fmt.Sprintf("https://%s:%s/healthcheck", os.Getenv("DOMAIN"), os.Getenv("PORT"))
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		os.Exit(1)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		os.Exit(2)
	}
	defer res.Body.Close()
	body, _ := ioutil.ReadAll(res.Body)
	fmt.Println(string(body))
}
