Elasticsearch Lightweight Client
================================

## DEPRECATED! DON'T USE THIS. USE OFFICIAL ELASTIC JAVASCRIPT CLIENT

Promise based simple client for elasticsearch.

## Installing

    npm install eslight

## Using

    ESLight = require 'eslight'

    es = new ESLight('http://my-es-node-1:9200/')

    (es.exec 'myindex', mytype', 'mydoc').then (res) ->
        console.log 'And the result it', res
    .fail (err) ->
        console.log 'Uh oh', err

    (es.exec 'PUT', 'myindex', mytype', 'mydoc', {some object...}).then (res) ->
        console.log 'And the result it', res
    .fail (err) ->
        console.log 'Uh oh', err

## `ESLight(string, ...)` or `ESLight(url, ...)`

The constructor takes a variable number endpoints as either `string`
or `url` objects. The `url` object is of the kind that `url.parse`
returns.

The endpoints will be used for round robin access to distribute load
and retries if any endpoint fails.

The arguments can be one or multiple strings or one or multiple arrays
of strings.

## `exec([verb], path part, ..., [query], [body])`

### `[verb]`
The exec method has a flexible number of arguments. The first argument
can be an optional HTTP string verb, one of `GET`, `POST`, `PUT`,
`DELETE`. If not provided the verb defaults to `GET`.

### `path part`

There must be at least one string path part. Each path part will be
joined with a `/`. The following examples are equivalent:

* `exec('myindex', 'mytype', 'mydoc')`
* `exec('myindex/mytype', 'mydoc')`
* `exec('myindex/mytype/mydoc')`
* `exec('/myindex/mytype/mydoc')`

### `[body]`

The body is optional and will be submitted if the last argument is of
`object` type. Remember that `typeof null == 'object'`.

    exec 'PUT', 'myindex/mytype/mydoc', {some:'doc', to:'store'}

### `[query]`

The query is optional, and will only be used if there is a body
part. To have only a query and no body, the last argument must be
`null`.

Optimistic locking as in `/myindex/mytype/mydoc?version=4`:

    exec 'PUT', 'myindex/mytype/mydoc', {version:4}, {some:'doc', to:'store'}

Notice `null` in this case:

    exec 'GET', 'myindex/mytype/mydoc/_search', {q:'find this'}, null
