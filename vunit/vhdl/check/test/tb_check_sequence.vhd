-- This test suite verifies the check_sequence checker.
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2016, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_base_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.log_types_pkg.all;
use vunit_lib.check_types_pkg.all;
use vunit_lib.check_special_types_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.log_base_pkg.all;
use vunit_lib.log_special_types_pkg.all;
use vunit_lib.string_ops.all;
use work.test_support.all;
use work.test_count.all;

entity tb_check_sequence is
  generic (
    runner_cfg : string);
end entity tb_check_sequence;

architecture test_fixture of tb_check_sequence is
  signal clk : std_logic := '0';
  signal one : std_logic := '1';
  signal zero : std_logic := '0';

  type slv_vector is array (natural range <>) of std_logic_vector(1 to 5);
  constant n_checks : positive := 5;
  signal inp : slv_vector(1 to n_checks) := (others => "00000");
  signal en : std_logic := '0';
  signal event_sequence : std_logic_vector(23 downto 20) := "0000";

  signal start_check_sequence_4 : boolean := false;
  shared variable checker_2, checker_3, checker_4, checker_5 : checker_t;
begin
  clock: process is
  begin
    while runner.phase < test_runner_exit loop
      clk <= '1', '0' after 5 ns;
      wait for 10 ns;
    end loop;
    wait;
  end process clock;

  check_sequence_1 : check_sequence(clk,
                                    inp(1)(5),
                                    inp(1)(1 to 4),
                                    trigger_event => first_pipe);

  check_sequence_2 : check_sequence(checker_2,
                                    clk,
                                    inp(2)(5),
                                    inp(2)(1 to 4),
                                    trigger_event => penultimate);

  check_sequence_3 : check_sequence(checker_3,
                                    clk,
                                    inp(3)(5),
                                    inp(3)(1 to 4),
                                    trigger_event => first_no_pipe);

  check_sequence_4 : process
  begin
    wait until start_check_sequence_4;
    check_sequence(checker_4, clk, inp(4)(5), inp(4)(1 to 1), result("for my data"));
    wait;
  end process;

  check_sequence_5 : check_sequence(checker_5,
                                    clk,
                                    inp(5)(5),
                                    inp(5)(1 to 4),
                                    result("for my data"),
                                    trigger_event => first_pipe);

  check_sequence_6 : check_sequence(clk,
                                    en,
                                    event_sequence,
                                    trigger_event => first_no_pipe);

  check_sequence_runner : process
    variable pass : boolean;
    variable stat : checker_stat_t;
    constant pass_level : log_level_t := debug_low2;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test should fail on sequences shorter than two events") then
        start_check_sequence_4 <= true;
        wait for 1 ns;
        verify_log_call(inc_count,
                        "Sequence check failed for my data - Event sequence length must be at least 2. Got 1.");
      elsif run("Test should pass a penultimate triggered pipelined and sequentially asserted event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(checker_2, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2,stat, 1);
        verify_failed_checks(checker_2,stat, 0);
        apply_sequence("0010.1;0001.1;0000.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2,stat, 2);
        verify_failed_checks(checker_2,stat, 0);
        apply_sequence("0000.1;1000.1;0100.1;0000.1;0001.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2,stat, 2);
        verify_failed_checks(checker_2,stat, 0);
      elsif run("Test should fail a penultimate triggered but interrupted event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(checker_2, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2, stat, 1);
        verify_failed_checks(checker_2, stat, 0);
        apply_sequence("0010.1;0000.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2, stat, 1);
        verify_failed_checks(checker_2, stat, 1);
        verify_log_call(inc_count,
                        "Sequence check failed - Missing required event at 3rd active and enabled clock edge.");
      elsif run("Test should pass a first triggered pipelined and sequentially asserted event sequence when pipelining is supported") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 0);
      elsif run("Test should fail a first triggered but interrupted event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0000.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
        apply_sequence("0000.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 1);
        verify_log_call(inc_count,
                        "Sequence check failed - Missing required event at 2nd active and enabled clock edge.");
      elsif run("Test should ignore a first triggered and simulataneously initiated event sequence when pipelining is not supported") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(checker_3, stat);
        apply_sequence("0000.1;1000.1;0100.1;1010.1;0101.1;0010.1", clk, inp(3));
        wait for 1 ns;
        verify_passed_checks(checker_3, stat, 1);
        verify_failed_checks(checker_3, stat, 0);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(3));
        wait for 1 ns;
        verify_passed_checks(checker_3, stat, 1);
        verify_failed_checks(checker_3, stat, 0);
      elsif run("Test should fail on unknowns in event sequence") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(checker_2, stat);
        apply_sequence("0000.1;1000.1;0100.1;10X0.1;0101.1;0010.1", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2, stat, 0);
        verify_failed_checks(checker_2, stat, 1);
        verify_log_call(inc_count, "Sequence check failed - Got 10X0.");
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2, stat, 1);
        get_checker_stat(stat);
        apply_sequence("0000.1;10X0.1;0100.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 1);
        verify_log_call(inc_count, "Sequence check failed - Got 10X0.");
        apply_sequence("0100.1;10X0.1;0101.1;0010.1", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 0);
        verify_failed_checks(stat, 3);
        apply_sequence("0010.1;0001.1;0000.0", clk, inp(1));
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 3);
        inc_count;
        inc_count;
        apply_sequence("0000.1;1000.1;1100.1;0X10.1;0011.1;0001.1;0000.1", clk, inp(1));
        verify_passed_checks(stat, 2);
        verify_failed_checks(stat, 5);
        clear_log_call_args;
        inc_count;
        inc_count;
      elsif run("Test should support weak high and low meta values") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(checker_2, stat);
        apply_sequence("0000.1;HL00.H;LH00.1;0010.1;000H.1;0000.0", clk, inp(2));
        wait for 1 ns;
        verify_passed_checks(checker_2, stat, 1);
        verify_failed_checks(checker_2, stat, 0);
      elsif run("Test should handle reversed and or offset expressions") then
        wait until rising_edge(clk);
        wait for 1 ns;
        get_checker_stat(stat);
        en <= '1';
        event_sequence <= "1000";
        wait until rising_edge(clk);
        event_sequence <= "0100";
        wait until rising_edge(clk);
        event_sequence <= "0010";
        wait until rising_edge(clk);
        event_sequence <= "0001";
        wait until rising_edge(clk);
        event_sequence <= "0000";
        en <= '0';
        wait for 1 ns;
        verify_passed_checks(stat, 1);
        verify_failed_checks(stat, 0);
      elsif run("Test pass message") then
        get_checker_stat(checker_5, stat);
        enable_pass_msg(checker_5);
        apply_sequence("0000.1;1000.1;0100.1;0010.1;0001.1;0000.1", clk, inp(5));
        wait for 1 ns;
        verify_log_call(inc_count, "Sequence check passed for my data", pass_level);
        disable_pass_msg(checker_5);
        verify_passed_checks(checker_5, stat, 1);
        verify_failed_checks(checker_5, stat, 0);
      end if;
    end loop;

    get_and_print_test_result(stat);
    test_runner_cleanup(runner, stat);
    wait;
  end process;

  test_runner_watchdog(runner, 2 us);

end test_fixture;

-- vunit_pragma run_all_in_same_sim
