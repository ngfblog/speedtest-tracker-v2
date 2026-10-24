<?php

namespace NgfBlog\Healthchecks\Tests;

use NgfBlog\Healthchecks\Exceptions\InvalidUrlException;
use NgfBlog\Healthchecks\Healthchecks;
use NgfBlog\Healthchecks\HealthchecksManager;

class InstantiationTest extends Test
{
    /**
     * Tests creating HM with invalid URL
     *
     * @return void
     */
    public function testInvalidURL()
    {
        try {
            $hm = new HealthchecksManager('abc', 'abc');
        } catch(InvalidUrlException $e) {
            $this->assertTrue(true);
            return true;
        }

        $this->assertTrue(false);
    }
}