[![Build Status](https://travis-ci.org/X-Plat/register_manager.png)](https://travis-ci.org/X-Plat/register_manager)

# register_manager

This repository contains the source code for a register manager
for x-plat.

## Summary

This register manager is used to register the instance with a n
aming service, especially for the rpc suitations.


## Getting started

The following instructions may help you get started with register
manager in a standalone environment.

### Setup

```
git clone https://github.com/X-Plat/register_manager
cd register_manager
bundle install
```

### Start

```
cd register_manager/bin
./register ../config/register.yml 
```

### Usage

Register manager process the `broker.register` and `borker.unregister`
message, and both of them are queued in `bk` group, which means any su
bscriber in the bk group could process the message.

```

## Notes

* 18/08/13: Code is now used on X-Plat
