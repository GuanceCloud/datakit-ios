//
//  FTCrashCPU.h
//  FTMobileSDK
//
//  Created by hulilei on 2024/11/18.
//  Copyright © 2024 DataFlux-cn. All rights reserved.
//

#ifndef FTCrashCPU_h
#define FTCrashCPU_h

#include <stdio.h>
#ifdef __cplusplus
extern "C" {
#endif

#include "FTCrashMachineContext.h"

#include <stdbool.h>
#include <stdint.h>

/** Get the current CPU architecture.
 *
 * @return The current architecture.
 */
const char *ftcrashcpu_currentArch(void);

/** Get the frame pointer for a machine context.
 * The frame pointer marks the top of the call stack.
 *
 * @param context The machine context.
 *
 * @return The context's frame pointer.
 */
uintptr_t ftcrashcpu_framePointer(const struct FTCrashMachineContext *const context);

/** Get the current stack pointer for a machine context.
 *
 * @param context The machine context.
 *
 * @return The context's stack pointer.
 */
uintptr_t ftcrashcpu_stackPointer(const struct FTCrashMachineContext *const context);

/** Get the address of the instruction about to be, or being executed by a
 * machine context.
 *
 * @param context The machine context.
 *
 * @return The context's next instruction address.
 */
uintptr_t ftcrashcpu_instructionAddress(const struct FTCrashMachineContext *const context);

/** Get the address stored in the link register (arm only). This may
 * contain the first return address of the stack.
 *
 * @param context The machine context.
 *
 * @return The link register value.
 */
uintptr_t ftcrashcpu_linkRegister(const struct FTCrashMachineContext *const context);

/** Get the address whose access caused the last fault.
 *
 * @param context The machine context.
 *
 * @return The faulting address.
 */
uintptr_t ftcrashcpu_faultAddress(const struct FTCrashMachineContext *const context);

/** Get the number of normal (not floating point or exception) registers the
 *  currently running CPU has.
 *
 * @return The number of registers.
 */
int ftcrashcpu_numRegisters(void);

/** Get the name of a normal register.
 *
 * @param regNumber The register index.
 *
 * @return The register's name or NULL if not found.
 */
const char *ftcrashcpu_registerName(int regNumber);

/** Get the value stored in a normal register.
 *
 * @param regNumber The register index.
 *
 * @return The register's current value.
 */
uint64_t ftcrashcpu_registerValue(
    const struct FTCrashMachineContext *const context, int regNumber);

/** Get the number of exception registers the currently running CPU has.
 *
 * @return The number of registers.
 */
int ftcrashcpu_numExceptionRegisters(void);

/** Get the name of an exception register.
 *
 * @param regNumber The register index.
 *
 * @return The register's name or NULL if not found.
 */
const char *ftcrashcpu_exceptionRegisterName(int regNumber);

/** Get the value stored in an exception register.
 *
 * @param regNumber The register index.
 *
 * @return The register's current value.
 */
uint64_t ftcrashcpu_exceptionRegisterValue(
    const struct FTCrashMachineContext *const context, int regNumber);

/** Get the direction in which the stack grows on the current architecture.
 *
 * @return 1 or -1, depending on which direction the stack grows in.
 */
int ftcrashcpu_stackGrowDirection(void);

/** Fetch the CPU state for this context and store it in the context.
 *
 * @param destinationContext The context to fill.
 */
void ftcrashcpu_getState(struct FTCrashMachineContext *destinationContext);

/** Strip PAC from an instruction pointer.
 *
 * @param ip PAC encoded instruction pointer.
 *
 * @return Instruction pointer without PAC.
 */
uintptr_t ftcrashcpu_normaliseInstructionPointer(uintptr_t ip);

#ifdef __cplusplus
}
#endif

#endif /* FTCrashCPU_h */
