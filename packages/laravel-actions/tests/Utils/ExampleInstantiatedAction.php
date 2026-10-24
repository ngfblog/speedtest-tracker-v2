<?php

namespace NgfBlog\LaravelActions\Tests\Utils;

use NgfBlog\LaravelActions\Interfaces\ActionInterface;

class ExampleInstantiatedAction implements ActionInterface
{
    public string $text;

    public function __construct(string $text)
    {
        $this->text = $text;
    }

    public function run()
    {
        return $this->text;
    }
}
