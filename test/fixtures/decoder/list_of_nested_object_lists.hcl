variable "foo" {
    default = "bar"
    description = "bar"
}

variable "amis" {
    default = {
        east = "foo"
    }
}

variable {
    foo = {
        hoge = "fuga"
    }
}