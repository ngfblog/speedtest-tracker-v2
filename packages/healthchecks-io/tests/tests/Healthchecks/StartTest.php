<?php

namespace NgfBlog\Healthchecks\Tests;

use NgfBlog\Healthchecks\Healthchecks;

class StartTest extends Test
{
    /**
     * Tests pinging a valid start endpoint
     *
     * @return void
     */
    public function test()
    {
        $hc = new Healthchecks($_ENV['UUID']);

        $this->assertTrue($hc->start());
    }
}