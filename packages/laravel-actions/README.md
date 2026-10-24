# Laravel Actions

A simple Laravel actions package.

## Installation

```bash
composer require ngfblog/laravel-actions
```

## Usage

To create a new action, run:

```bash
php artisan make:action <name>
```

This will create a new action in `App/Actions`. You can then use the action in one of two ways:

```php
$action = new SomeAction();
$action->run();
```

Or you can use the `run` helper function:

```php
run(SomeAction::class);
```

You can pass arguments for the action's run method as the subsequent arguments for the helper method:

```php
run(SomeAction::class, $arg);
run(SomeAction::class, $arg1, $arg2);
```

## License

MIT license. Please see the [license file](LICENSE.md) for more information.

