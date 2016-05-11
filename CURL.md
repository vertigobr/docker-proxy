OSX CURL
=======

Client certificates on OSX curl are broken.

Please install a different version with brew:

```
brew install curl --with-openssl
```

This takes time because curl will be compiled for you. Brew will not replace native curl (that would be careless), so your new curl will reside in a path like this (version may change, of course):

    /usr/local/Cellar/curl/7.48.0/bin/curl

You can use an alias to replace curl during your shell session:

```bash
alias curl=/usr/local/Cellar/curl/7.48.0/bin/curl
```

