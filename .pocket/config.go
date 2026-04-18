package main

import (
	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/markdown"
)

// Config is the Pocket configuration for this project.
// Edit this file to define your tasks and composition.
var Config = &pk.Config{
	Auto: pk.Serial(
		pk.Parallel(
			markdown.Tasks(),
			lua.Tasks(),
		),
		pk.WithOptions(
			github.Tasks(),
			pk.WithFlags(github.WorkflowFlags{
				Platforms: []github.Platform{github.Ubuntu},
			}),
		),
	),

	Plan: &pk.PlanConfig{
		Shims: &pk.ShimConfig{
			Posix: true,
		},
	},
}
