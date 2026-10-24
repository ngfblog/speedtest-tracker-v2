<?php

namespace NgfBlog\LaravelActions\Tests\Utils;

use NgfBlog\LaravelActions\Interfaces\ActionInterface;

class ExampleMultiArgumentAction implements ActionInterface
{
    public function run(string $text = null, string $text2 = null)
    {
        return $text.$text2;
    }
}
