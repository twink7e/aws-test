<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>POPER Operations Demo</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 48rem; margin: 5rem auto; padding: 0 1.5rem; color: #1d2939; }
        h1 { font-size: 2rem; margin-bottom: 2.5rem; }
        dt { color: #667085; margin-top: 1.5rem; }
        dd { font-size: 1.2rem; margin: .4rem 0 0; overflow-wrap: anywhere; }
    </style>
</head>
<body>
    <h1>POPER Operations Demo</h1>
    <dl>
        <dt>Environment message</dt>
        <dd>{{ $environmentMessage }}</dd>
        <dt>AppConfig message</dt>
        <dd>{{ $appConfigMessage ?? 'Configuration temporarily unavailable' }}</dd>
    </dl>
</body>
</html>
