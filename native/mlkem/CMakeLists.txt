# Builds libnyxpq (shared): PQClean's ML-KEM-768 (FIPS 203) "clean" C99
# implementation behind the small nyxpq_* ABI in nyxpq.h.
#
# Consumed by android/app/build.gradle.kts (externalNativeBuild) for the
# APK, and usable stand-alone for host builds:
#   cmake -S native/mlkem -B build/native-cmake && cmake --build build/native-cmake
cmake_minimum_required(VERSION 3.18)
project(nyxpq LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release)
endif()

set(NYXPQ_PQCLEAN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/pqclean")
set(NYXPQ_MLKEM_DIR "${NYXPQ_PQCLEAN_DIR}/crypto_kem/ml-kem-768/clean")
set(NYXPQ_COMMON_DIR "${NYXPQ_PQCLEAN_DIR}/common")

add_library(nyxpq SHARED
  nyxpq.c
  ${NYXPQ_COMMON_DIR}/fips202.c
  ${NYXPQ_COMMON_DIR}/randombytes.c
  ${NYXPQ_MLKEM_DIR}/cbd.c
  ${NYXPQ_MLKEM_DIR}/indcpa.c
  ${NYXPQ_MLKEM_DIR}/kem.c
  ${NYXPQ_MLKEM_DIR}/ntt.c
  ${NYXPQ_MLKEM_DIR}/poly.c
  ${NYXPQ_MLKEM_DIR}/polyvec.c
  ${NYXPQ_MLKEM_DIR}/reduce.c
  ${NYXPQ_MLKEM_DIR}/symmetric-shake.c
  ${NYXPQ_MLKEM_DIR}/verify.c
)

target_include_directories(nyxpq PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${NYXPQ_MLKEM_DIR}
  ${NYXPQ_COMMON_DIR}
)
target_compile_definitions(nyxpq PRIVATE NYXPQ_BUILD=1)

# Only the nyxpq_* symbols are exported (nyxpq.h marks them explicitly).
set_target_properties(nyxpq PROPERTIES
  C_VISIBILITY_PRESET hidden
  POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
  target_compile_options(nyxpq PRIVATE /O2 /W3)
else()
  # -O2 is applied last so it wins over the configuration's default (-O0 in
  # Android debug builds, -O3 in Release), matching PQClean's tested flags.
  target_compile_options(nyxpq PRIVATE -Wall -Wextra -Wpedantic -O2)
endif()

if(WIN32)
  # randombytes.c uses CryptGenRandom.
  target_link_libraries(nyxpq PRIVATE advapi32)
  # Produce nyxpq.dll (not libnyxpq.dll) so every toolchain agrees with the
  # Dart binding's lookup path.
  set_target_properties(nyxpq PROPERTIES PREFIX "")
endif()

if(ANDROID)
  # Android 15+ 16 KB page-size compatibility (NDK r28 already defaults to
  # this; stated explicitly so older NDKs behave the same).
  target_link_options(nyxpq PRIVATE "-Wl,-z,max-page-size=16384")
endif()
