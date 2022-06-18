package main

import (
	"context"
	"net/http"

	"github.com/snirkop89/greenlight/internal/data"
)

type contextKey string

const userConstextKey = contextKey("user")

func (app *application) contextSetUser(r *http.Request, user *data.User) *http.Request {
	ctx := context.WithValue(r.Context(), userConstextKey, user)
	return r.WithContext(ctx)
}

func (app *application) contextGetUser(r *http.Request) *data.User {
	user, ok := r.Context().Value(userConstextKey).(*data.User)
	if !ok {
		panic("missing user value in request context")
	}

	return user
}
