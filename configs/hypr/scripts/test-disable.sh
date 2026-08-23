#!/bin/bash
hyprctl keyword monitor "eDP-1,disable"
sleep 5
hyprctl keyword monitor "eDP-1,preferred,auto,1"
