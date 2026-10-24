<?php

namespace NgfBlog\LaravelActions\Tests\Utils;

use NgfBlog\LaravelActions\Interfaces\ActionInterface;

class ExampleNoArgumentAction implements ActionInterface
{
    public function run()
    {
        return 'Hello';
    }
}
