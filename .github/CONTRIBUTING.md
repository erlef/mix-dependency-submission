# Contributing to `mix-dependency-submission`

## Welcome!

We look forward to your contributions! Here are some examples how you can
contribute:

- [Report a bug](https://github.com/erlef/mix-dependency-submission/issues/new?type=bug)
- [Propose a new feature](https://github.com/erlef/mix-dependency-submission/issues/new?type=feature)
- [Send a pull request](https://github.com/erlef/mix-dependency-submission/pulls)

## We have a Code of Conduct

Please note that this project is released with a
[Contributor Code of Conduct](https://github.com/erlef/.github/blob/main/CODE_OF_CONDUCT.md).
By participating in this project you agree to abide by its terms.

## Any contributions you make will be under the Apache 2.0 License

When you submit code changes, your submissions are understood to be under the
same [Apache 2.0](https://github.com/erlef/mix-dependency-submission/blob/main/LICENSE)
that covers the project. By contributing to this project, you agree that your
contributions will be licensed under its Apache 2.0 License.

## Write bug reports with detail, background, and sample code

In your bug report, please provide the following:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you
- tried that didn't work)

Please do not report a bug for a version of `mix-dependency-submission` that is
not up-to-date.

Please post code and output as text
([using proper markup](https://guides.github.com/features/mastering-markdown/)).
Do not post screenshots of code or output.

## Workflow for Pull Requests

1. Fork the repository.
2. Create your branch from `main` if you plan to implement new functionality or
   change existing code significantly; create your branch from the oldest branch
   that is affected by the bug if you plan to fix a bug.
3. Implement your change and add tests for it.
4. Ensure the test suite passes.
5. Ensure the code complies with our coding guidelines (see below).
6. Send that pull request!

Please make sure you have
[set up your user name and email address](https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup)
for use with Git. Strings such as `silly nick name <root@localhost>` look really
stupid in the commit history of a project.

We encourage you to
[sign your Git commits with your GPG key](https://docs.github.com/en/github/authenticating-to-github/signing-commits).

Pull requests for new features must be based on the `main` branch.

We are trying to keep backwards compatibility breaks in `mix-dependency-submission`
to a minimum. Please take this into account when proposing changes.

Due to time constraints, we are not always able to respond as quickly as we
would like. Please do not take delays personal and feel free to remind us if you
feel that we forgot to respond.

## Coding Guidelines

This project comes with configured linters (located in `.credo.exs` in the
repository) that you can use to perform various checks:

```bash
$ mix credo
```

This project comes with configuration (located in `.formatter.exs` in the
repository) that you can use to (re)format your source code for compliance with
this project's coding guidelines:

```bash
$ mix format
```

This project uses `dialyzer` to perform static code checking. Run it to make
sure that your code is valid:

```bash
$ mix dialyzer
```

Please understand that we will not accept a pull request when its changes
violate this project's coding guidelines.

## Using `mix-dependency-submission` from a Git checkout

The following commands can be used to perform the initial checkout of
`mix-dependency-submission`:

```bash
$ git clone git@github.com:erlef/mix-dependency-submission.git

$ cd mix-dependency-submission
```

Install `mix-dependency-submission`'s dependencies using
[mix](https://hexdocs.pm/mix/Mix.html):

```bash
$ mix deps.get
```

## Running `mix-dependency-submission`'s test suite

After following the steps shown above, `mix-dependency-submission`'s test suite
is run like this:

```bash
$ mix test
```

## Generating `mix-dependency-submission` Documentation

To generate the documentation for the library, run:

```bash
$ mix docs
```

## How-To Release

* Update `@version` in `mix.exs`
* Update `version` in `action.yml` / `steps` / `Download Dependency Submission Tool`
* Update `version` in `action.yml` / `steps` / `Verify Dependency Submission Tool Provenance`
* `git commit -m "Release v[VERSION]"`
* `git tag -s v[VERSION] -m v[VERSION]`
* If stable release:
  * `git checkout v[MAJOR_VERSION]`
  * `git merge main`
* `git push origin main v[MAJOR_VERSION] --tags`

## How-To Update Erlang / Elixir

* Update Versions in `.tool-versions`
* Put the same versions into `action.yaml` / `steps` / `setup-beam`
* Put the same versions into `mix.exs` / `project/0` / `:elixir`