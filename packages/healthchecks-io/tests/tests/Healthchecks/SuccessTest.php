<?php

namespace NgfBlog\Healthchecks\Tests;

use NgfBlog\Healthchecks\Healthchecks;

class SuccessTest extends Test
{
    /**
     * Tests pinging a valid success endpoint
     *
     * @return void
     */
    public function test()
    {
        $hc = new Healthchecks($_ENV['UUID']);

        $this->assertTrue($hc->success());
    }
}