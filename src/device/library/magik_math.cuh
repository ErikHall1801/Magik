/*
*     Style guide;
*    - Templates should be used whenever possible 
*    - All functions are "auto" by default 
*    - __inline__ constexpr are used to use CUDA intrinsics 
*    
*    Contents;
*    1. Typedefs
*    2. Complex numbers
*        - Struct (complex_type<>)
*        - (Operators)
*        - (Functions)
*    3. Dual numbers
*        - Struct (dual_type<>)
*        - (Operators)
*        - (Functions)
*    4. 2-vector 
*        - Struct (vector_two_type<T>)
*        - (Operators)
*        - (Functions)
*    5. 3-vector (vector_three_type<T>)
*        - Struct
*        - (Operators)
*        - (Functions)
*    6. 4-vector (vector_four_type<T>)
*        - Struct
*        - (Operators)
*        - (Functions)
*    7. General vector functions
*    8. Quaternion
*        - Struct
*        - (Operators)
*        - (Functions)
*    9. Matrix 2 (matrix_two_type<T>)
*        - Struct
*        - (Operators)
*    10. Matrix 3 (matrix_three_type<T>)
*        - Struct
*        - (Operators)
*        - (Functions)
*    11. Matrix 4 (matrix_four_type<T>)
*        - Struct
*        - (Operators)
*    12. Utility
*        - Probability
*            - Random 2-vector
*            - Random 3-vector
*            - cosine weighted z axis alligned 3-vector
*            - triplet32 hash
*        - lerp
*        - map_range
*        - angle conversion
*        - clamp
*        - smooth step
*        - smooth ramp
*        - fraction 
*        - swap
*        - coordinate transformation
*            - Z-axis aligned
*        - numerical solvers
*            - solve_ode_rkf45
*            - solve_ode_rk4
*            - solve_ode_explicit_euler
*        - numerical root finders
*            - root_bisection
*            - root_newton
*            - root_newton_automatic_differentiation
*            - root_brent_dekker
*        - noise
*            - 2D Cell worley
*            - 3D Cell worley
*            - bokeh noise
*        - Physics
*            - Spectral Power Distributions
*        - Fourier Transform
*/

#pragma once

namespace magik::math
{
    // ##########################
    // ### Typedefs & defines ###
    // ##########################
        __device__ __constant__ constexpr float pi = 3.14159265358979323846f;
        __device__ __constant__ constexpr float speed_of_light = 299792458.0f;
        __device__ __constant__ constexpr float planck_constant = 6.62607015E-34f;
        __device__ __constant__ constexpr float boltzmann_constant = 1.380649E-23f;
        __device__ __constant__ constexpr float gravitational_constant = 6.67430E-11f;
        __device__ __constant__ constexpr float elementary_charge = 1.60217663E-19f;
        __device__ __constant__ constexpr float electron_mass = 9.1093837E-31f;

        using ::sqrt;
        using ::pow;
        using ::exp;
        using ::log;
        using ::sin;
        using ::cos;
        using ::tan;
        using ::atan2;
        using std::min;
        using std::max;



    // #######################
    // ### Complex numbers ###
    // #######################
        // Struct
        template<typename T_real, typename T_imag> struct complex_type
        {
            T_real real = static_cast<T_real>(0.0);
            T_imag imag = static_cast<T_imag>(0.0);

            // Conjugate
            __device__ __host__ __inline__ constexpr auto conjugate() const 
            {
                return complex_type<T_real, T_imag>{ real, -imag };
            }

            // Modules
            __device__ __host__ __inline__ constexpr auto modulus() const 
            {
                return sqrt(real * real + imag * imag);
            }

            __device__ __host__ __inline__ constexpr auto modulus_2() const 
            {
                return (real * real + imag * imag);
            }

            // Argument
            __device__ __host__ __inline__ constexpr auto arg() const
            {
                return atan2(imag, real);
            }
        };

        // Operators
        // Addition; complex_type + complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator+(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return complex_type<T_real, T_imag>{ a.real + b.real, a.imag + b.imag };
        }

        // Subtraction; complex_type - complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator-(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return complex_type<T_real, T_imag>{ a.real - b.real, a.imag - b.imag };
        }

        // Multiplication; compex_type * compex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator*(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return complex_type<T_real, T_imag>{ (a.real * b.real) - (a.imag * b.imag), (a.real * b.imag) + (a.imag * b.real) };
        }

        // Multiplication; complex_type * T_real
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator*(complex_type<T_real, T_imag> a, T_real b)
        {
            return complex_type<T_real, T_imag>{ a.real * b, a.imag * b };
        }

        // Multiplication; T_real * complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator*(T_real a, complex_type<T_real, T_imag> b)
        {
            return complex_type<T_real, T_imag>{ a * b.real, a * b.imag };
        }

        // Division; complex_type / complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator/(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return complex_type<T_real, T_imag>{ ((a.real * b.real) + (a.imag * b.imag)) / ((b.real * b.real) + (b.imag * b.imag)), ((a.imag * b.real) - (a.real * b.imag)) / ((b.real * b.real) + (b.imag * b.imag)) };
        }

        // Division; complex_type / scalar
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator/(complex_type<T_real, T_imag> a, T_real b)
        {
            T_real inv_b = static_cast<T_real>(1.0) / b; 
            return complex_type<T_real, T_imag>{ a.real * inv_b, a.imag * inv_b };
        }

        // Compound; +=
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator+=(complex_type<T_real, T_imag>& a, const complex_type<T_real, T_imag>& b)
        {
            a.real += b.real;
            a.imag += b.imag;
            return a;
        }

        // Compound; -=
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator-=(complex_type<T_real, T_imag>& a, const complex_type<T_real, T_imag>& b)
        {
            a.real -= b.real;
            a.imag -= b.imag;
            return a;
        }

        // Compound; complex_type *= complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator*=(complex_type<T_real, T_imag>& a, const complex_type<T_real, T_imag>& b)
        {
            T_real temp_real = (a.real * b.real) - (a.imag * b.imag);
            a.imag = (a.real * b.imag) + (a.imag * b.real);
            a.real = temp_real;
            return a;
        }

        // Compound; complex_type *= T
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator*=(complex_type<T_real, T_imag>& a, const T_real& b)
        {
            complex_type<T_real, T_imag> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; complex_type /= complex_type
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator/=(complex_type<T_real, T_imag>& a, const complex_type<T_real, T_imag>& b)
        {
            complex_type<T_real, T_imag> complex_temp = a/b;
            a = complex_temp;
            return a;
        }

        // Compound; complex_type /= T
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr complex_type<T_real, T_imag>& operator/=(complex_type<T_real, T_imag>& a, const T_real& b)
        {
            complex_type<T_real, T_imag> temp = a/b;
            a = temp;
            return a;
        }

        // Comparison; ==
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator==(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real == b.real) && (a.imag == b.imag);
        }

        // Comparison; !=
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator!=(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real != b.real) || (a.imag != b.imag);
        }

        // Comparison; >=
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator>=(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real >= b.real) && (a.imag >= b.imag);
        }

        // Comparison; <=
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator<=(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real <= b.real) && (a.imag <= b.imag);
        }

        // Comparison; >
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator>(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real > b.real) && (a.imag > b.imag);
        }

        // Comparison; <
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator<(complex_type<T_real, T_imag> a, complex_type<T_real, T_imag> b)
        {
            return (a.real < b.real) && (a.imag < b.imag);
        }

        // Inverse; -
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator-(complex_type<T_real, T_imag> a)
        {
            return complex_type<T_real, T_imag>{-a.real, -a.imag};
        }

        // Inverse; +
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto operator+(complex_type<T_real, T_imag> a)
        {
            return complex_type<T_real, T_imag>{+a.real, +a.imag};
        }

        // Functions
        // sqrt
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto sqrt(complex_type<T_real, T_imag> a)
        {
            // Branch cut along negative real axis to follow std::sqrt(std::complex) standard
            T_real x = a.real;
            T_real y = a.imag;

            if(x == static_cast<T_real>(0.0) && y == static_cast<T_real>(0.0))
            {
                return complex_type<T_real, T_imag>{ static_cast<T_real>(0.0), static_cast<T_imag>(0.0) };
            }

            T_real mag = ::hypot(x, y);
            T_real w = ::sqrt((mag + ::abs(x)) / static_cast<T_real>(2.0));

            T_real x2, y2;

            if (x >= static_cast<T_real>(0.0)) 
            {
                x2 = w;
                y2 = y / (static_cast<T_real>(2.0) * w);
            } 
            else 
            {
                x2 = ::abs(y) / (static_cast<T_real>(2.0) * w);
                y2 = (y >= static_cast<T_real>(0.0)) ? w : -w;
            }

            return complex_type<T_real, T_imag>{ x2, y2 };
        }

        // Nth power
        template<typename T_real, typename T_imag> __device__ __host__ __inline__ constexpr auto pow(complex_type<T_real, T_imag> z, T_real n)
        {
            T_real x = z.real;
            T_real y = z.imag;

            if (x == static_cast<T_real>(0.0) && y == static_cast<T_real>(0.0))
            {
                if (n == static_cast<T_real>(0.0)) 
                {
                    return complex_type<T_real, T_imag>{ static_cast<T_real>(1.0), static_cast<T_imag>(0.0) };
                }
                else if (n > static_cast<T_real>(0.0))
                {
                    return complex_type<T_real, T_imag>{ static_cast<T_real>(0.0), static_cast<T_imag>(0.0) };
                }
            }

            T_real abs_r = z.modulus();
            T_real arg = z.arg();
            
            using ::pow;
            T_real r_n = pow(abs_r, n);
            T_real theta_n = n * arg;

            T_real cos_theta, sin_theta;

            cos_theta = cos(theta_n);
            sin_theta = sin(theta_n);

            return complex_type<T_real, T_imag>{ r_n * cos_theta, static_cast<T_imag>(r_n * sin_theta)};
        }



    // ####################
    // ### Dual numbers ###
    // ####################
        // Struct
        template<typename T_real, typename T_dual> struct dual_type
        {
            T_real real = static_cast<T_real>(0.0);
            T_dual dual = static_cast<T_dual>(0.0);

            // Conjugate
            __device__ __host__ __inline__ constexpr auto conjugate() const
            {
                return dual_type<T_real, T_dual>{real, -dual};
            }
        };

        // Operators
        // Addition; dual_type + dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator+(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a.real + b.real, a.dual + b.dual };
        }

        // Addition; dual_type + T_real
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator+(dual_type<T_real, T_dual> a, T_real b)
        {
            return dual_type<T_real, T_dual>{ a.real + b, a.dual };
        }

        // Addition; T_real + dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator+(T_real a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a + b.real, b.dual };
        }

        // Subtraction; dual_type - dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator-(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a.real - b.real, a.dual - b.dual };
        }

        // Subtraction; dual_type - T_real
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator-(dual_type<T_real, T_dual> a, T_real b)
        {
            return dual_type<T_real, T_dual>{ a.real - b, a.dual };
        }

        // Subtraction; T_real - dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator-(T_real a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a - b.real, -b.dual };
        }

        // Multiplication; dual_type * dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator*(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a.real * b.real, b.real * a.dual + a.real * b.dual };
        }

        // Multiplication; dual_type * T_real
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator*(dual_type<T_real, T_dual> a, T_real b)
        {
            return dual_type<T_real, T_dual>{ a.real * b, a.dual * b };
        }

        // Multiplication; T_real * dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto operator*(T_real a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a * b.real, a * b.dual };
        }

        // Division; dual_type / dual_type
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator/(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a.real / b.real, (a.dual / b.real) - (a.real * b.dual) / (b.real * b.real) };
        }

        // Division; dual_type / T_real
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator/(dual_type<T_real, T_dual> a, T_real b)
        {
            return dual_type<T_real, T_dual>{ a.real / b, a.dual / b};
        }

        // Division; T_real / dual_type
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator/(T_real a, dual_type<T_real, T_dual> b)
        {
            return dual_type<T_real, T_dual>{ a / b.real, -(a / (b.real * b.real)) * b.dual };
        }

        // Compound; +=
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator+=(dual_type<T_real, T_dual>& a, const dual_type<T_real, T_dual>& b)
        {
            a.real += b.real;
            a.dual += b.dual;
            return a;
        }

        // Compound; -=
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator-=(dual_type<T_real, T_dual>& a, const dual_type<T_real, T_dual>& b)
        {
            a.real -= b.real;
            a.dual -= b.dual;
            return a;
        }

        // Compound; dual_type *= dual_type
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator*=(dual_type<T_real, T_dual>& a, const dual_type<T_real, T_dual>& b)
        {
            dual_type<T_real, T_dual> dual_temp = a*b;
            a = dual_temp;
            return a;
        }

        // Compound; dual_type *= T
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator*=(dual_type<T_real, T_dual>& a, const T_real& b)
        {
            dual_type<T_real, T_dual> dual_temp = a*b;
            a = dual_temp;
            return a;
        }

        // Compound; /=
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator/=(dual_type<T_real, T_dual>& a, const dual_type<T_real, T_dual>& b)
        {
            dual_type<T_real, T_dual> dual_temp = a/b;
            a = dual_temp;
            return a;
        }

        // Compound; dual_type /= T
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr dual_type<T_real, T_dual>& operator/=(dual_type<T_real, T_dual>& a, const T_real& b)
        {
            dual_type<T_real, T_dual> dual_temp = a/b;
            a = dual_temp;
            return a;
        }

        // Comparison; ==
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator==(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real == b.real);
        }

        // Comparison; !=
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator!=(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real != b.real);
        }

        // Comparison; >=
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator>=(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real >= b.real);
        }

        // Comparison; <=
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator<=(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real <= b.real);
        }

        // Comparison; >
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator>(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real > b.real);
        }

        // Comparison; <
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator<(dual_type<T_real, T_dual> a, dual_type<T_real, T_dual> b)
        {
            return (a.real < b.real);
        }

        // Inverse; -
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator-(dual_type<T_real, T_dual> a)
        {
            return dual_type<T_real, T_dual>{-a.real, -a.dual};
        }

        // Inverse; +
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto operator+(dual_type<T_real, T_dual> a)
        {
            return dual_type<T_real, T_dual>{+a.real, +a.dual};
        }

        // Functions
        // sqrt
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto sqrt(dual_type<T_real, T_dual> a)
        {
            using ::sqrt;
            T_real sqrt_real = sqrt(a.real);
            return dual_type<T_real, T_dual>{sqrt_real, static_cast<T_dual>(0.5) * a.dual / sqrt_real};
        }

        // Exponential
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto exp(dual_type<T_real, T_dual> a)
        {
            using ::exp;
            T_real e_x = exp(a.real);
            return dual_type<T_real, T_dual>{ e_x, a.dual * e_x };
        }

        // Natural logarithm
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto log(dual_type<T_real, T_dual> a)
        {
            using ::log;
            return dual_type<T_real, T_dual>{log(a.real), a.dual / a.real};
        }

        // Nth Power
        template<typename T_real, typename T_dual>  __device__ __host__ __inline__ constexpr auto pow(dual_type<T_real, T_dual> a, T_real n)
        {
            using ::pow;
            T_real real_pow = pow(a.real, n);
            T_real deriv = n * pow(a.real, n - static_cast<T_real>(1.0));
            return dual_type<T_real, T_dual>{ real_pow, a.dual * deriv };
        }

        // Sin
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto sin(dual_type<T_real, T_dual> a)
        {
            using ::sin;
            using ::cos;
            return dual_type<T_real, T_dual>{ sin(a.real), a.dual * cos(a.real) };
        }

        // Cos
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto cos(dual_type<T_real, T_dual> a)
        {
            using ::sin;
            using ::cos;
            return dual_type<T_real, T_dual>{ cos(a.real), -a.dual * sin(a.real) };
        }

        // Tan
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto tan(dual_type<T_real, T_dual> a)
        {
            using ::tan;
            using ::cos;
            T_real cos_x = cos(a.real);
            return dual_type<T_real, T_dual>{tan(a.real), a.dual / (cos_x * cos_x)};
        }

        // Absolute
        template<typename T_real, typename T_dual> __device__ __host__ __inline__ constexpr auto abs(dual_type<T_real, T_dual> a)
        {
            using ::abs;
            T_real sign =   (a.real > static_cast<T_real>(0.0)) ? static_cast<T_real>(1.0) : 
                            (a.real < static_cast<T_real>(0.0)) ? static_cast<T_real>(-1.0) : static_cast<T_real>(0.0);
            return dual_type<T_real, T_dual>{ abs(a.real), a.dual * sign };
        }



    // ################
    // ### 2-vector ###
    // ################
        // Struct
        template<typename T> struct two_vector_type
        {
            T x = static_cast<T>(0);
            T y = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto xy() const
            {
                return two_vector_type<T>{x, y};
            }

            __device__ __host__ __inline__ constexpr auto length() const 
            {
                using ::sqrt;
                return sqrt(x*x + y*y);
            }

            __device__ __host__ __inline__ constexpr auto length2() const
            {
                return (x*x + y*y);
            }

            __device__ __host__ __inline__ constexpr auto norm() const
            {
                T len = this->length();
                return two_vector_type<T>{x / len, y / len};
            }

            __device__ __host__ __inline__ constexpr auto& make_norm()
            {
                two_vector_type<T> n_vec = this->norm();
                *this = n_vec;
                return *this;
            }
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(two_vector_type<T> a, two_vector_type<T> b)
        {
            return two_vector_type<T>{ a.x + b.x, a.y + b.y };
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(two_vector_type<T> a, two_vector_type<T> b)
        {
            return two_vector_type<T>{ a.x - b.x, a.y - b.y };
        }

        // Multiplication
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(two_vector_type<T> a, two_vector_type<T> b)
        {
            return two_vector_type<T>{ a.x * b.x, a.y * b.y };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(two_vector_type<T> a, T b)
        {
            return two_vector_type<T>{ a.x * b, a.y * b };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T a, two_vector_type<T> b)
        {
            return two_vector_type<T>{ a * b.x, a * b.y };
        }

        // Division; two_vector_type / two_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(two_vector_type<T> a, two_vector_type<T> b)
        {
            return two_vector_type<T>{ a.x / b.x, a.y / b.y };
        }

        // Division; two_vector_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(two_vector_type<T> a, T b)
        {
            return two_vector_type<T>{ a.x / b, a.y / b };
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator+=(two_vector_type<T>& a, const two_vector_type<T>& b)
        {
            a.x += b.x;
            a.y += b.y;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator-=(two_vector_type<T>& a, const two_vector_type<T>& b)
        {
            a.x -= b.x;
            a.y -= b.y;
            return a;
        }

        // Compound; two_vector_type *= two_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator*=(two_vector_type<T>& a, const two_vector_type<T>& b)
        {
            two_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; two_vector_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator*=(two_vector_type<T>& a, const T& b)
        {
            two_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; two_vector_type /= two_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator/=(two_vector_type<T>& a, const two_vector_type<T>& b)
        {
            two_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Compound; two_vector_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr two_vector_type<T>& operator/=(two_vector_type<T>& a, const T& b)
        {
            two_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x == b.x) && (a.y == b.y);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x != b.x) || (a.y != b.y);
        }

        // Comparison; >=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>=(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x >= b.x) && (a.y >= b.y);
        }

        // Comparison; <=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<=(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x <= b.x) && (a.y <= b.y);
        }

        // Comparison; >
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x > b.x) && (a.y > b.y);
        }

        // Comparison; <
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<(two_vector_type<T> a, two_vector_type<T> b)
        {
            return (a.x < b.x) && (a.y < b.y);
        }

        // Inverse; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(two_vector_type<T> a)
        {
            return two_vector_type<T>{-a.x, -a.y};
        }

        // Inverse; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(two_vector_type<T> a)
        {
            return two_vector_type<T>{+a.x, +a.y};
        }

        // Functions
        // dot product
        template<typename T> __device__ __host__ __inline__ constexpr auto vector_dot_product(two_vector_type<T> a, two_vector_type<T> b)
        {
            return ((a.x*b.x) + (a.y*b.y));
        }

        // cross product
        template<typename T> __device__ __host__ __inline__ constexpr auto vector_perpendicular(two_vector_type<T> a)
        {
            return two_vector_type<T>{-a.y, a.x};
        }



    // ################
    // ### 3-vector ###
    // ################
        // Struct
        template<typename T> struct three_vector_type
        {
            T x = static_cast<T>(0);
            T y = static_cast<T>(0);
            T z = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto xy() const
            {
                return two_vector_type<T>{x, y};
            }

            __device__ __host__ __inline__ constexpr auto xyz() const
            {
                return three_vector_type<T>{x, y, z};
            }

            __device__ __host__ __inline__ constexpr auto length() const 
            {
                using ::sqrt;
                return sqrt(x*x + y*y + z*z);
            }

            __device__ __host__ __inline__ constexpr auto length2() const
            {
                return (x*x + y*y + z*z);
            }

            __device__ __host__ __inline__ constexpr auto norm() const
            {
                T len = this->length();
                return three_vector_type<T>{x / len, y / len, z / len};
            }

            __device__ __host__ __inline__ constexpr auto& make_norm()
            {
                three_vector_type<T> n_vec = this->norm();
                *this = n_vec;
                return *this;
            }
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(three_vector_type<T> a, three_vector_type<T> b)
        {
            return three_vector_type<T>{ a.x + b.x, a.y + b.y, a.z + b.z };
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(three_vector_type<T> a, three_vector_type<T> b)
        {
            return three_vector_type<T>{ a.x - b.x, a.y - b.y, a.z - b.z };
        }

        // Multiplication
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(three_vector_type<T> a, three_vector_type<T> b)
        {
            return three_vector_type<T>{ a.x * b.x, a.y * b.y, a.z * b.z };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(three_vector_type<T> a, T b)
        {
            return three_vector_type<T>{ a.x * b, a.y * b, a.z * b };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T a, three_vector_type<T> b)
        {
            return three_vector_type<T>{ a * b.x, a * b.y, a * b.z };
        }

        // Division; three_vector_type / three_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(three_vector_type<T> a, three_vector_type<T> b)
        {
            return three_vector_type<T>{ a.x / b.x, a.y / b.y, a.z / b.z };
        }

        // Division; three_vector_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(three_vector_type<T> a, T b)
        {
            return three_vector_type<T>{ a.x / b, a.y / b, a.z / b };
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator+=(three_vector_type<T>& a, const three_vector_type<T>& b)
        {
            a.x += b.x;
            a.y += b.y;
            a.z += b.z;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator-=(three_vector_type<T>& a, const three_vector_type<T>& b)
        {
            a.x -= b.x;
            a.y -= b.y;
            a.z -= b.z;
            return a;
        }

        // Compound; three_vector_type *= three_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator*=(three_vector_type<T>& a, const three_vector_type<T>& b)
        {
            three_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; three_vector_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator*=(three_vector_type<T>& a, const T& b)
        {
            three_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; three_vector_type /= three_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator/=(three_vector_type<T>& a, const three_vector_type<T>& b)
        {
            three_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Compound; three_vector_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr three_vector_type<T>& operator/=(three_vector_type<T>& a, const T& b)
        {
            three_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x == b.x) && (a.y == b.y) && (a.z == b.z);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x != b.x) || (a.y != b.y) || (a.z != b.z);
        }

        // Comparison; >=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>=(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x >= b.x) && (a.y >= b.y) && (a.z >= b.z);
        }

        // Comparison; <=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<=(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x <= b.x) && (a.y <= b.y) && (a.z <= b.z);
        }

        // Comparison; >
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x > b.x) && (a.y > b.y) && (a.z > b.z);
        }

        // Comparison; <
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<(three_vector_type<T> a, three_vector_type<T> b)
        {
            return (a.x < b.x) && (a.y < b.y) && (a.z < b.z);
        }

        // Inverse; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(three_vector_type<T> a)
        {
            return three_vector_type<T>{-a.x, -a.y, -a.z};
        }

        // Inverse; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(three_vector_type<T> a)
        {
            return three_vector_type<T>{+a.x, +a.y, +a.z};
        }

        // Functions
        // dot product
        template<typename T> __device__ __host__ __inline__ constexpr auto vector_dot_product(three_vector_type<T> a, three_vector_type<T> b)
        {
            return ((a.x*b.x) + (a.y*b.y) + (a.z*b.z));
        }

        // cross product
        template<typename T> __device__ __host__ __inline__ constexpr auto vector_cross_product(three_vector_type<T> a, three_vector_type<T> b)
        {
            return three_vector_type<T>{a.y*b.z - a.z*b.y , a.z*b.x - a.x*b.z , a.x*b.y - a.y*b.x};
        }



    // ################
    // ### 4-vector ###
    // ################
        // Struct
        template<typename T> struct four_vector_type
        {
            T x = static_cast<T>(0);
            T y = static_cast<T>(0);
            T z = static_cast<T>(0);
            T t = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto xy() const
            {
                return two_vector_type<T>{x, y};
            }

            __device__ __host__ __inline__ constexpr auto xyz() const
            {
                return three_vector_type<T>{x, y, z};
            }

            __device__ __host__ __inline__ constexpr auto length() const 
            {
                using ::sqrt;
                return sqrt(x*x + y*y + z*z + t*t);
            }

            __device__ __host__ __inline__ constexpr auto length2() const
            {
                return (x*x + y*y + z*z + t*t);
            }

            __device__ __host__ __inline__ constexpr auto norm() const
            {
                T len = this->length();
                return four_vector_type<T>{x / len, y / len, z / len, t / len};
            }

            __device__ __host__ __inline__ constexpr auto& make_norm()
            {
                four_vector_type<T> n_vec = this->norm();
                *this = n_vec;
                return *this;
            }
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(four_vector_type<T> a, four_vector_type<T> b)
        {
            return four_vector_type<T>{ a.x + b.x, a.y + b.y, a.z + b.z, a.t + b.t };
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(four_vector_type<T> a, four_vector_type<T> b)
        {
            return four_vector_type<T>{ a.x - b.x, a.y - b.y, a.z - b.z, a.t - b.t };
        }

        // Multiplication
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(four_vector_type<T> a, four_vector_type<T> b)
        {
            return four_vector_type<T>{ a.x * b.x, a.y * b.y, a.z * b.z, a.t * b.t };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(four_vector_type<T> a, T b)
        {
            return four_vector_type<T>{ a.x * b, a.y * b, a.z * b, a.t * b };
        }

        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T a, four_vector_type<T> b)
        {
            return four_vector_type<T>{ a * b.x, a * b.y, a * b.z, a * b.t };
        }

        // Division; four_vector_type / four_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(four_vector_type<T> a, four_vector_type<T> b)
        {
            return four_vector_type<T>{ a.x / b.x, a.y / b.y, a.z / b.z, a.t / b.t };
        }

        // Division; four_vector_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(four_vector_type<T> a, T b)
        {
            return four_vector_type<T>{ a.x / b, a.y / b, a.z / b, a.t / b };
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator+=(four_vector_type<T>& a, const four_vector_type<T>& b)
        {
            a.x += b.x;
            a.y += b.y;
            a.z += b.z;
            a.t += b.t;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator-=(four_vector_type<T>& a, const four_vector_type<T>& b)
        {
            a.x -= b.x;
            a.y -= b.y;
            a.z -= b.z;
            a.t -= b.t;
            return a;
        }

        // Compound; four_vector_type *= four_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator*=(four_vector_type<T>& a, const four_vector_type<T>& b)
        {
            four_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; four_vector_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator*=(four_vector_type<T>& a, const T& b)
        {
            four_vector_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; four_vector_type /= four_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator/=(four_vector_type<T>& a, const four_vector_type<T>& b)
        {
            four_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Compound; four_vector_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr four_vector_type<T>& operator/=(four_vector_type<T>& a, const T& b)
        {
            four_vector_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x == b.x) && (a.y == b.y) && (a.z == b.z) && (a.t == b.t);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x != b.x) || (a.y != b.y) || (a.z != b.z) || (a.t != b.t);
        }

        // Comparison; >=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>=(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x >= b.x) && (a.y >= b.y) && (a.z >= b.z) && (a.t >= b.t);
        }

        // Comparison; <=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<=(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x <= b.x) && (a.y <= b.y) && (a.z <= b.z) && (a.t <= b.t);
        }

        // Comparison; >
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x > b.x) && (a.y > b.y) && (a.z > b.z) && (a.t > b.t);
        }

        // Comparison; <
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<(four_vector_type<T> a, four_vector_type<T> b)
        {
            return (a.x < b.x) && (a.y < b.y) && (a.z < b.z) && (a.t < b.t);
        }

        // Inverse; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(four_vector_type<T> a)
        {
            return four_vector_type<T>{-a.x, -a.y, -a.z, -a.t};
        }

        // Inverse; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(four_vector_type<T> a)
        {
            return four_vector_type<T>{+a.x, +a.y, +a.z, +a.t};
        }

        // Functions
        // dot product
        template<typename T> __device__ __host__ __inline__ constexpr auto vector_dot_product(four_vector_type<T> a, four_vector_type<T> b)
        {
            return ((a.x*b.x) + (a.y*b.y) + (a.z*b.z)) + (a.t*b.t);
        }



    // ################################
    // ### General vector functions ###
    // ################################
        // reflect
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_reflect(T_Vector<T_component> a, T_Vector<T_component> n)
        {
            return (a - (static_cast<T_component>(2.0) * n * magik::math::vector_dot_product(a, n)));
        }

        // refract
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_refract(T_Vector<T_component> a, T_Vector<T_component> n, T_component eta_0, T_component eta_1)
        {
            T_component cos_theta_i = magik::math::vector_dot_product(a, n);
            T_component eta_relative = eta_0 / eta_1;
            T_component sin2_theta_t = eta_relative * eta_relative * (static_cast<T_component>(1.0) - cos_theta_i * cos_theta_i);
            using ::sqrt;
            return (eta_relative * cos_theta_i - sqrt(static_cast<T_component>(1.0) - sin2_theta_t)) * n - eta_relative * a;
        }

        // project
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_project(T_Vector<T_component> a, T_Vector<T_component> b)
        {
            return (magik::math::vector_dot_product(a, b) * b) / magik::math::vector_dot_product(b, b);
        }

        // distance
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_distance(T_Vector<T_component> a, T_Vector<T_component> b)
        {
            T_Vector<T_component> temp = a-b;
            return temp.length();
        }

        // distance2
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_distance2(T_Vector<T_component> a, T_Vector<T_component> b)
        {
            T_Vector<T_component> temp = a-b;
            return temp.length2();
        }

        // angle
        template<template<typename> class T_Vector, typename T_component> __device__ __host__ __inline__ constexpr auto vector_angle(T_Vector<T_component> a, T_Vector<T_component> b)
        {
            using ::acos;
            return acos(magik::math::vector_dot_product(a.norm(), b.norm()));
        }



    // ##################
    // ### Quaternion ###
    // ##################
        // Struct
        template<typename T> struct quaternion_type
        {
            T w = static_cast<T>(0);
            T x = static_cast<T>(0);
            T y = static_cast<T>(0);
            T z = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto length2() const
            {
                return (w*w + x*x + y*y + z*z);
            }

            __device__ __host__ __inline__ constexpr auto length() const
            {
                using ::sqrt;
                return sqrt(w*w + x*x + y*y + z*z);
            }

            __device__ __host__ __inline__ constexpr auto conjugate() const
            {
                return quaternion_type<T>{w, -x, -y, -z};
            }

            __device__ __host__ __inline__ constexpr auto norm() const
            {
                T len = this->length();
                quaternion_type<T> q = {w / len, x / len, y / len, z / len};
                return q;
            }

            __device__ __host__ __inline__ constexpr auto inverse() const
            {
                T len2 = this->length2();
                quaternion_type<T> conj = this->conjugate();
                return quaternion_type<T>{ conj.w / len2, conj.x / len2, conj.y / len2, conj.z / len2 };
            }

            __device__ __host__ __inline__ constexpr auto& make_conjugate()
            {
                quaternion_type<T> q = {static_cast<T>(w), static_cast<T>(-x), static_cast<T>(-y), static_cast<T>(-z)};
                *this = q;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_identity()
            {
                quaternion_type<T> q = {static_cast<T>(1.0), static_cast<T>(0), static_cast<T>(0), static_cast<T>(0)};
                *this = q;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_norm()
            {
                T len = this->length();
                *this = quaternion_type<T>{w / len, x / len, y / len, z / len};
                return *this;
            }
        };

        // Operators
        // Addition; quaternion_type + quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(quaternion_type<T> a, quaternion_type<T> b)
        {
            return quaternion_type<T>{ a.w + b.w, a.x + b.x, a.y + b.y, a.z + b.z};
        }

        // Subtraction; quaternion_type - quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(quaternion_type<T> a, quaternion_type<T> b)
        {
            return quaternion_type<T>{ a.w - b.w, a.x - b.x, a.y - b.y, a.z - b.z };
        }

        // Multiplication; quaternion_type * quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(quaternion_type<T> a, quaternion_type<T> b)
        {
            return quaternion_type<T>{  a.w*b.w - a.x*b.x - a.y*b.y - a.z*b.z,
                                        a.w*b.x + a.x*b.w + a.y*b.z - a.z*b.y,
                                        a.w*b.y - a.x*b.z + a.y*b.w + a.z*b.x,
                                        a.w*b.z + a.x*b.y - a.y*b.x + a.z*b.w };
        }

        // Multiplication; quaternion_type * T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(quaternion_type<T> a, T b)
        {
            return quaternion_type<T>{ a.w * b, a.x * b, a.y * b, a.z * b };
        }

        // Multiplication; T * quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T a, quaternion_type<T> b)
        {
            return quaternion_type<T>{ a * b.w, a * b.x, a * b.y, a * b.z };
        }

        // Division; quaternion_type / quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(quaternion_type<T> a, quaternion_type<T> b)
        {
            return a*b.inverse();
        }

        // Division; quaternion_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(quaternion_type<T> a, T b)
        {
            return quaternion_type<T>{ a.w / b, a.x / b, a.y / b, a.z / b };
        }

        // Division; T / quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(T a, quaternion_type<T> b)
        {
            return a*b.inverse();
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator+=(quaternion_type<T>& a, quaternion_type<T> b)
        {
            a.w += b.w;
            a.x += b.x;
            a.y += b.y;
            a.z += b.z;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator-=(quaternion_type<T>& a, quaternion_type<T> b)
        {
            a.w -= b.w;
            a.x -= b.x;
            a.y -= b.y;
            a.z -= b.z;
            return a;
        }

        // Compound; quaternion_type *= quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator*=(quaternion_type<T>& a, quaternion_type<T> b)
        {
            quaternion_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; quaternion_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator*=(quaternion_type<T>& a, T b)
        {
            quaternion_type<T> temp = a*b;
            a = temp;
            return a;
        }

        // Compound; quaternion_type /= quaternion_type
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator/=(quaternion_type<T>& a, quaternion_type<T> b)
        {
            quaternion_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Compound; quaternion_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr quaternion_type<T>& operator/=(quaternion_type<T>& a, T b)
        {
            quaternion_type<T> temp = a/b;
            a = temp;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w == b.w) && (a.x == b.x) && (a.y == b.y) && (a.z == b.z);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w != b.w) || (a.x != b.x) || (a.y != b.y) || (a.z != b.z);
        }

        // Comparison; >=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>=(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w >= b.w) && (a.x >= b.x) && (a.y >= b.y) && (a.z >= b.z);
        }

        // Comparison; <=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<=(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w <= b.w) && (a.x <= b.x) && (a.y <= b.y) && (a.z <= b.z);
        }

        // Comparison; >
        template<typename T> __device__ __host__ __inline__ constexpr auto operator>(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w > b.w) && (a.x > b.x) && (a.y > b.y) && (a.z > b.z);
        }

        // Comparison; <
        template<typename T> __device__ __host__ __inline__ constexpr auto operator<(quaternion_type<T> a, quaternion_type<T> b)
        {
            return (a.w < b.w) && (a.x < b.x) && (a.y < b.y) && (a.z < b.z);
        }

        // Inverse; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(quaternion_type<T> a)
        {
            return quaternion_type<T>{-a.w, -a.x, -a.y, -a.z};
        }

        // Inverse; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(quaternion_type<T> a)
        {
            return quaternion_type<T>{+a.w, +a.x, +a.y, +a.z};
        }

        // Functions
        // Dot product
        template<typename T> __device__ __host__ __inline__ constexpr auto quaternion_dot_product(quaternion_type<T> a, quaternion_type<T> b)
        {
            return a.w*b.w + a.x*b.x + a.y*b.y + a.z*b.z;
        }

        // Quaternion from axis angle
        template<typename T> __device__ __host__ __inline__ constexpr auto quaternion_from_axis_angle(T angle_radians, T ax, T ay, T az)
        {
            // ax, ay and az are the axis arong which we rotate, so for a rotation around x they are 1,0,0
            using ::sin;
            using ::cos;
            T half_angle = angle_radians / static_cast<T>(2.0);
            T s = sin(half_angle);
            return quaternion_type<T>{cos(half_angle), ax*s, ay*s, az*s};
        }

        // vector rotation
        template<typename T> __device__ __host__ __inline__ constexpr auto quaternion_vector_rotate(quaternion_type<T> q_unit, three_vector_type<T> p)
        {
            // Using the sandwhich product, q_unit must be normalized ! 
            quaternion_type<T> p_q = {static_cast<T>(0), p.x, p.y, p.z};
            quaternion_type<T> p_dot = q_unit*p_q*q_unit.conjugate();
            return three_vector_type<T>{p_dot.x, p_dot.y, p_dot.z};
        }



    // ################
    // ### 2-Matrix ###
    // ################
        // Struct
        template<typename T> struct matrix_two_type
        {
            T m11 = static_cast<T>(0); T m12 = static_cast<T>(0);
            T m21 = static_cast<T>(0); T m22 = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto determinant() const 
            {
                return m11*m22 - m21*m12;
            }

            __device__ __host__ __inline__ constexpr auto transpose() const 
            {
                return matrix_two_type<T>{  m11, m21,
                                            m12, m22 };
            }

            __device__ __host__ __inline__ constexpr auto rotate(const T theta) const 
            {
                using ::cos;
                using ::sin;
                T cos_theta = cos(theta);
                T sin_theta = sin(theta);
                matrix_two_type<T> m = matrix_two_type<T>{  static_cast<T>(cos_theta), static_cast<T>(-sin_theta),
                                                            static_cast<T>(sin_theta), static_cast<T>(cos_theta) };
                return m;
            }

            __device__ __host__ __inline__ constexpr auto& make_transpose()
            {
                matrix_two_type<T> m = matrix_two_type<T>{  m11, m21,
                                                            m12, m22 };

                *this = m;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_identity()
            {
                matrix_two_type<T> m = matrix_two_type<T>{  static_cast<T>(1.0), static_cast<T>(0),
                                                            static_cast<T>(0), static_cast<T>(1.0) };
                *this = m;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_rotate(const T theta) 
            {
                using ::cos;
                using ::sin;
                T cos_theta = cos(theta);
                T sin_theta = sin(theta);
                matrix_two_type<T> m = matrix_two_type<T>{  static_cast<T>(cos_theta), static_cast<T>(-sin_theta),
                                                            static_cast<T>(sin_theta), static_cast<T>(cos_theta) };

                *this = m;
                return *this;
            }
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_two_type<T> M0, matrix_two_type<T> M1)
        {
            matrix_two_type<T> result;
            result.m11 = M0.m11 + M1.m11;
            result.m12 = M0.m12 + M1.m12;
            result.m21 = M0.m21 + M1.m21;
            result.m22 = M0.m22 + M1.m22;
            return result;
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_two_type<T> M0, matrix_two_type<T> M1)
        {
            matrix_two_type<T> result;
            result.m11 = M0.m11 - M1.m11;
            result.m12 = M0.m12 - M1.m12;
            result.m21 = M0.m21 - M1.m21;
            result.m22 = M0.m22 - M1.m22;
            return result;
        }

        // Multiplication; matrix_two_type * matrix_two_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_two_type<T> M0, matrix_two_type<T> M1)
        {
            matrix_two_type<T> result;
            result.m11 = M0.m11*M1.m11 + M0.m12*M1.m21;
            result.m12 = M0.m11*M1.m12 + M0.m12*M1.m22;
            result.m21 = M0.m21*M1.m11 + M0.m22*M1.m21;
            result.m22 = M0.m21*M1.m12 + M0.m22*M1.m22;
            return result;
        }

        // Multiplication; matrix_two_type * T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_two_type<T> M, T s)
        {
            matrix_two_type<T> result;
            result.m11 = M.m11*s;
            result.m12 = M.m12*s;
            result.m21 = M.m21*s;
            result.m22 = M.m22*s;
            return result;
        }

        // Multiplication; T * matrix_two_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T s, matrix_two_type<T> M)
        {
            matrix_two_type<T> result;
            result.m11 = s*M.m11;
            result.m12 = s*M.m12;
            result.m21 = s*M.m21;
            result.m22 = s*M.m22;
            return result;
        }

        // Multiplication; matrix_two_type * two_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_two_type<T> M, two_vector_type<T> V)
        {
            two_vector_type<T> result;
            result.x = M.m11*V.x + M.m12*V.y;
            result.y = M.m21*V.x + M.m22*V.y;
            return result;
        }

        // Division; matrix_two_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(matrix_two_type<T> M, T s)
        {
            matrix_two_type<T> result;
            result.m11 = M.m11/s;
            result.m12 = M.m12/s;
            result.m21 = M.m21/s;
            result.m22 = M.m22/s;
            return result;
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_two_type<T>& operator+=(matrix_two_type<T>& M0, const matrix_two_type<T> M1)
        {
            matrix_two_type<T> M_temp = M0 + M1;
            M0 = M_temp;
            return M0;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_two_type<T>& operator-=(matrix_two_type<T>& M0, const matrix_two_type<T> M1)
        {
            matrix_two_type<T> M_temp = M0 - M1;
            M0 = M_temp;
            return M0;
        }

        // Compound; matrix_two_type *= matrix_two_type
        template<typename T> __device__ __host__ __inline__ constexpr matrix_two_type<T>& operator*=(matrix_two_type<T>& M0, const matrix_two_type<T> M1)
        {
            matrix_two_type<T> M_temp = M0 * M1;
            M0 = M_temp;
            return M0;
        }

        // Compound; matrix_two_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_two_type<T>& operator*=(matrix_two_type<T>& M, const T s)
        {
            matrix_two_type<T> M_temp = M * s;
            M = M_temp;
            return M;
        }

        // Compound; matrix_two_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_two_type<T>& operator/=(matrix_two_type<T>& M, const T s)
        {
            matrix_two_type<T> M_temp = M / s;
            M = M_temp;
            return M;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(matrix_two_type<T> M0, matrix_two_type<T> M1)
        {
            return (M0.m11 == M1.m11) && (M0.m12 == M1.m12) && (M0.m21 == M1.m21) && (M0.m22 == M1.m22);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(matrix_two_type<T> M0, matrix_two_type<T> M1)
        {
            return (M0.m11 != M1.m11) || (M0.m12 != M1.m12) || (M0.m21 != M1.m21) || (M0.m22 != M1.m22);
        }

        // Inversion; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_two_type<T> M)
        {
            matrix_two_type<T> result;
            result.m11 = -M.m11;
            result.m12 = -M.m12;
            result.m21 = -M.m21;
            result.m22 = -M.m22;
            return result;
        }

        // Inversion; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_two_type<T> M)
        {
            matrix_two_type<T> result;
            result.m11 = +M.m11;
            result.m12 = +M.m12;
            result.m21 = +M.m21;
            result.m22 = +M.m22;
            return result;
        }



    // ################
    // ### 3-Matrix ###
    // ################
        // Struct
        template<typename T> struct matrix_three_type
        {
            T m11 = static_cast<T>(0); T m12 = static_cast<T>(0); T m13 = static_cast<T>(0);
            T m21 = static_cast<T>(0); T m22 = static_cast<T>(0); T m23 = static_cast<T>(0);
            T m31 = static_cast<T>(0); T m32 = static_cast<T>(0); T m33 = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto determinant() const 
            {
                return m11*(m22*m33 - m23*m32) - m12*(m21*m33 - m23*m31) + m13*(m21*m32 - m22*m31);
            }

            __device__ __host__ __inline__ constexpr auto transpose() const 
            {
                matrix_three_type<T> m = {  m11, m21, m31,
                                            m12, m22, m32,
                                            m13, m23, m33 };
                return m;
            }

            __device__ __host__ __inline__ constexpr auto rotate(const T alpha, const T beta, const T gamma) const;

            __device__ __host__ __inline__ constexpr auto& make_transpose()
            {
                matrix_three_type<T> m = {  m11, m21, m31,
                                            m12, m22, m32,
                                            m13, m23, m33 };
                *this = m;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_identity()
            {
                matrix_three_type<T> m = {  static_cast<T>(1), static_cast<T>(0), static_cast<T>(0),
                                            static_cast<T>(0), static_cast<T>(1), static_cast<T>(0),
                                            static_cast<T>(0), static_cast<T>(0), static_cast<T>(1) };
                *this = m;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_rotate(const T alpha, const T beta, const T gamma);
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_three_type<T> a, matrix_three_type<T> b)
        {
            return matrix_three_type<T> {   a.m11 + b.m11, a.m12 + b.m12, a.m13 + b.m13,
                                            a.m21 + b.m21, a.m22 + b.m22, a.m23 + b.m23,
                                            a.m31 + b.m31, a.m32 + b.m32, a.m33 + b.m33 };
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_three_type<T> a, matrix_three_type<T> b)
        {
            return matrix_three_type<T> {   a.m11 - b.m11, a.m12 - b.m12, a.m13 - b.m13,
                                            a.m21 - b.m21, a.m22 - b.m22, a.m23 - b.m23,
                                            a.m31 - b.m31, a.m32 - b.m32, a.m33 - b.m33 };
        }

        // Multiplication; matrix_three_type * matrix_three_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_three_type<T> a, matrix_three_type<T> b)
        {
            return matrix_three_type<T> {   a.m11*b.m11 + a.m12*b.m21 + a.m13*b.m31, a.m11*b.m12 + a.m12*b.m22 + a.m13*b.m32, a.m11*b.m13 + a.m12*b.m23 + a.m13*b.m33,
                                            a.m21*b.m11 + a.m22*b.m21 + a.m23*b.m31, a.m21*b.m12 + a.m22*b.m22 + a.m23*b.m32, a.m21*b.m13 + a.m22*b.m23 + a.m23*b.m33,
                                            a.m31*b.m11 + a.m32*b.m21 + a.m33*b.m31, a.m31*b.m12 + a.m32*b.m22 + a.m33*b.m32, a.m31*b.m13 + a.m32*b.m23 + a.m33*b.m33 };
        }

        // Multiplication; matrix_three_type * three_vector_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_three_type<T> m, three_vector_type<T> v)
        {
            return three_vector_type<T>{    m.m11 * v.x + m.m12 * v.y + m.m13 * v.z,
                                            m.m21 * v.x + m.m22 * v.y + m.m23 * v.z,
                                            m.m31 * v.x + m.m32 * v.y + m.m33 * v.z };
        }

        // Multiplication; matrix_three_type * T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_three_type<T> a, T s)
        {
            return matrix_three_type<T> {   a.m11*s, a.m12*s, a.m13*s,
                                            a.m21*s, a.m22*s, a.m23*s,
                                            a.m31*s, a.m32*s, a.m33*s };
        }

        // Multiplication; T * matrix_three_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T s, matrix_three_type<T> a)
        {
            return matrix_three_type<T> {   s*a.m11, s*a.m12, s*a.m13,
                                            s*a.m21, s*a.m22, s*a.m23,
                                            s*a.m31, s*a.m32, s*a.m33 };
        }

        // Division; matrix_three_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(matrix_three_type<T> a, T s)
        {
            return matrix_three_type<T> {   a.m11/s, a.m12/s, a.m13/s,
                                            a.m21/s, a.m22/s, a.m23/s,
                                            a.m31/s, a.m32/s, a.m33/s };
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_three_type<T>& operator+=(matrix_three_type<T>& a, const matrix_three_type<T> b)
        {
            matrix_three_type<T> c = a + b;
            a = c;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_three_type<T>& operator-=(matrix_three_type<T>& a, const matrix_three_type<T> b)
        {
            matrix_three_type<T> c = a - b;
            a = c;
            return a;
        }

        // Compound; matrix_three_type *= matrix_three_type
        template<typename T> __device__ __host__ __inline__ constexpr matrix_three_type<T>& operator*=(matrix_three_type<T>& a, const matrix_three_type<T> b)
        {
            matrix_three_type<T> c = a * b;
            a = c;
            return a;
        }

        // Compound; matrix_three_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_three_type<T>& operator*=(matrix_three_type<T>& a, const T s)
        {
            matrix_three_type<T> c = a * s;
            a = c;
            return a;
        }

        // Compound; matrix_three_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_three_type<T>& operator/=(matrix_three_type<T>& a, const T s)
        {
            matrix_three_type<T> c = a / s;
            a = c;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(matrix_three_type<T> a, matrix_three_type<T> b)
        {
            return  (a.m11 == b.m11) && (a.m12 == b.m12) && (a.m13 == b.m13) &&
                    (a.m21 == b.m21) && (a.m22 == b.m22) && (a.m23 == b.m23) &&
                    (a.m31 == b.m31) && (a.m32 == b.m32) && (a.m33 == b.m33);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(matrix_three_type<T> a, matrix_three_type<T> b)
        {
            return  (a.m11 != b.m11) || (a.m12 != b.m12) || (a.m13 != b.m13) ||
                    (a.m21 != b.m21) || (a.m22 != b.m22) || (a.m23 != b.m23) ||
                    (a.m31 != b.m31) || (a.m32 != b.m32) || (a.m33 != b.m33);
        }

        // Inversion; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_three_type<T> a)
        {
            return matrix_three_type<T>{    -a.m11, -a.m12, -a.m13,
                                            -a.m21, -a.m22, -a.m23,
                                            -a.m31, -a.m32, -a.m33 };
        }

        // Inversion; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_three_type<T> a)
        {
            return matrix_three_type<T>{    +a.m11, +a.m12, +a.m13,
                                            +a.m21, +a.m22, +a.m23,
                                            +a.m31, +a.m32, +a.m33 };
        }

        // Functions
        // Rotate
        template<typename T> __device__ __host__ __inline__ constexpr auto matrix_three_type<T>::rotate(const T alpha, const T beta, const T gamma) const
        {
            using ::sin;
            using ::cos;

            T cos_alpha = cos(alpha);
            T sin_alpha = sin(alpha);
            T cos_beta = cos(beta);
            T sin_beta = sin(beta);
            T cos_gamma = cos(gamma);
            T sin_gamma = sin(gamma);

            matrix_three_type<T> m_x, m_y, m_z;

            m_z = {  cos_alpha, -sin_alpha, static_cast<T>(0), 
                    sin_alpha, cos_alpha, static_cast<T>(0),
                    static_cast<T>(0), static_cast<T>(0), static_cast<T>(1) };

            m_y = {  cos_beta, static_cast<T>(0), sin_beta, 
                    static_cast<T>(0), static_cast<T>(1), static_cast<T>(0),
                    -sin_beta, static_cast<T>(0), cos_beta };

            m_x = {  static_cast<T>(1), static_cast<T>(0), static_cast<T>(0), 
                    static_cast<T>(0), cos_gamma, -sin_gamma, 
                    static_cast<T>(0), sin_gamma, cos_gamma };
                
            return m_x*m_y*m_z;
        }

        // Make rotate
        template<typename T> __device__ __host__ __inline__ constexpr auto& matrix_three_type<T>::make_rotate(const T alpha, const T beta, const T gamma)
        {
            matrix_three_type<T> m_rot = this->rotate(alpha, beta, gamma);
            *this = m_rot;
            return *this;
        }



    // ################
    // ### 4-Matrix ###
    // ################
        // Struct
        template<typename T> struct matrix_four_type
        {
            T m11 = static_cast<T>(0); T m12 = static_cast<T>(0); T m13 = static_cast<T>(0); T m14 = static_cast<T>(0);
            T m21 = static_cast<T>(0); T m22 = static_cast<T>(0); T m23 = static_cast<T>(0); T m24 = static_cast<T>(0);
            T m31 = static_cast<T>(0); T m32 = static_cast<T>(0); T m33 = static_cast<T>(0); T m34 = static_cast<T>(0);
            T m41 = static_cast<T>(0); T m42 = static_cast<T>(0); T m43 = static_cast<T>(0); T m44 = static_cast<T>(0);

            __device__ __host__ __inline__ constexpr auto determinant() const
            {
                return  m11*m22*m33*m44 + m11*m23*m34*m42 + m11*m24*m32*m43 -
                        m11*m24*m33*m43 - m11*m23*m32*m44 - m11*m22*m34*m43 -
                        m12*m21*m33*m44 - m13*m21*m34*m42 - m14*m21*m32*m43 +
                        m14*m21*m33*m43 + m13*m21*m32*m44 + m12*m21*m34*m43 +
                        m12*m23*m31*m44 + m13*m24*m31*m42 + m14*m22*m31*m43 -
                        m14*m23*m31*m42 - m13*m22*m31*m44 - m12*m24*m31*m43 -
                        m12*m23*m34*m41 - m13*m24*m32*m41 - m14*m22*m33*m41 +
                        m14*m23*m32*m41 + m13*m22*m34*m41 + m12*m24*m33*m41;
            }

            __device__ __host__ __inline__ constexpr auto transpose() const 
            {
                return matrix_four_type<T>{ m11, m21, m31, m41,
                                            m12, m22, m32, m42,
                                            m13, m23, m33, m43,
                                            m14, m24, m34, m44 };
            }

            __device__ __host__ __inline__ constexpr auto& make_transpose()
            {
                matrix_four_type<T> c = this->transpose();
                *this = c;
                return *this;
            }

            __device__ __host__ __inline__ constexpr auto& make_identity()
            {
                matrix_four_type<T> c =   { static_cast<T>(1), static_cast<T>(0), static_cast<T>(0), static_cast<T>(0),
                                            static_cast<T>(0), static_cast<T>(1), static_cast<T>(0), static_cast<T>(0),
                                            static_cast<T>(0), static_cast<T>(0), static_cast<T>(1), static_cast<T>(0),
                                            static_cast<T>(0), static_cast<T>(0), static_cast<T>(0), static_cast<T>(1) };
                *this = c;
                return *this;
            }
        };

        // Operators
        // Addition
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_four_type<T> a, matrix_four_type<T> b)
        {
            return matrix_four_type<T>{ a.m11 + b.m11, a.m12 + b.m12, a.m13 + b.m13, a.m14 + b.m14, 
                                        a.m21 + b.m21, a.m22 + b.m22, a.m23 + b.m23, a.m24 + b.m24, 
                                        a.m31 + b.m31, a.m32 + b.m32, a.m33 + b.m33, a.m34 + b.m34, 
                                        a.m41 + b.m41, a.m42 + b.m42, a.m43 + b.m43, a.m44 + b.m44, };
        }

        // Subtraction
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_four_type<T> a, matrix_four_type<T> b)
        {
            return matrix_four_type<T>{ a.m11 - b.m11, a.m12 - b.m12, a.m13 - b.m13, a.m14 - b.m14, 
                                        a.m21 - b.m21, a.m22 - b.m22, a.m23 - b.m23, a.m24 - b.m24, 
                                        a.m31 - b.m31, a.m32 - b.m32, a.m33 - b.m33, a.m34 - b.m34, 
                                        a.m41 - b.m41, a.m42 - b.m42, a.m43 - b.m43, a.m44 - b.m44, };
        }

        // Multiplication; matrix_four_type * matrix_four_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_four_type<T> a, matrix_four_type<T> b)
        {
            return matrix_four_type<T>{ (a.m11*b.m11 + a.m12*b.m21 + a.m13*b.m31 + a.m14*b.m41), (a.m11*b.m12 + a.m12*b.m22 + a.m13*b.m32 + a.m14*b.m42), (a.m11*b.m13 + a.m12*b.m23 + a.m13*b.m33 + a.m14*b.m43), (a.m11*b.m14 + a.m12*b.m24 + a.m13*b.m34 + a.m14*b.m44),
                                        (a.m21*b.m11 + a.m22*b.m21 + a.m23*b.m31 + a.m24*b.m41), (a.m21*b.m12 + a.m22*b.m22 + a.m23*b.m32 + a.m24*b.m42), (a.m21*b.m13 + a.m22*b.m23 + a.m23*b.m33 + a.m24*b.m43), (a.m21*b.m14 + a.m22*b.m24 + a.m23*b.m34 + a.m24*b.m44),
                                        (a.m31*b.m11 + a.m32*b.m21 + a.m33*b.m31 + a.m34*b.m41), (a.m31*b.m12 + a.m32*b.m22 + a.m33*b.m32 + a.m34*b.m42), (a.m31*b.m13 + a.m32*b.m23 + a.m33*b.m33 + a.m34*b.m43), (a.m31*b.m14 + a.m32*b.m24 + a.m33*b.m34 + a.m34*b.m44),
                                        (a.m41*b.m11 + a.m42*b.m21 + a.m43*b.m31 + a.m44*b.m41), (a.m41*b.m12 + a.m42*b.m22 + a.m43*b.m32 + a.m44*b.m42), (a.m41*b.m13 + a.m42*b.m23 + a.m43*b.m33 + a.m44*b.m43), (a.m41*b.m14 + a.m42*b.m24 + a.m43*b.m34 + a.m44*b.m44) };
        }

        // Multiplication; matrix_four_type * vector_four_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_four_type<T> m, four_vector_type<T> v)
        {
            return four_vector_type<T>{ m.m11 * v.x + m.m12 * v.y + m.m13 * v.z + m.m14 * v.t,
                                        m.m21 * v.x + m.m22 * v.y + m.m23 * v.z + m.m24 * v.t,
                                        m.m31 * v.x + m.m32 * v.y + m.m33 * v.z + m.m34 * v.t,
                                        m.m41 * v.x + m.m42 * v.y + m.m43 * v.z + m.m44 * v.t };
        }

        // Multiplication; matrix_four_type * T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(matrix_four_type<T> a, T s)
        {
            return matrix_four_type<T>{ a.m11*s, a.m12*s, a.m13*s, a.m14*s,
                                        a.m21*s, a.m22*s, a.m23*s, a.m24*s,
                                        a.m31*s, a.m32*s, a.m33*s, a.m34*s,
                                        a.m41*s, a.m42*s, a.m43*s, a.m44*s };
        }

        // Multiplication; T * matrix_four_type
        template<typename T> __device__ __host__ __inline__ constexpr auto operator*(T s, matrix_four_type<T> a)
        {
            return matrix_four_type<T>{ s*a.m11, s*a.m12, s*a.m13, s*a.m14,
                                        s*a.m21, s*a.m22, s*a.m23, s*a.m24,
                                        s*a.m31, s*a.m32, s*a.m33, s*a.m34,
                                        s*a.m41, s*a.m42, s*a.m43, s*a.m44 };
        }

        // Division; matrix_four_type / T
        template<typename T> __device__ __host__ __inline__ constexpr auto operator/(matrix_four_type<T> a, T s)
        {
            return matrix_four_type<T>{ a.m11/s, a.m12/s, a.m13/s, a.m14/s,
                                        a.m21/s, a.m22/s, a.m23/s, a.m24/s,
                                        a.m31/s, a.m32/s, a.m33/s, a.m34/s,
                                        a.m41/s, a.m42/s, a.m43/s, a.m44/s };
        }

        // Compound; +=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_four_type<T>& operator+=(matrix_four_type<T>& a, const matrix_four_type<T> b)
        {
            matrix_four_type<T> c = a + b;
            a = c;
            return a;
        }

        // Compound; -=
        template<typename T> __device__ __host__ __inline__ constexpr matrix_four_type<T>& operator-=(matrix_four_type<T>& a, const matrix_four_type<T> b)
        {
            matrix_four_type<T> c = a - b;
            a = c;
            return a;
        }

        // Compound; matrix_four_type *= matrix_four_type
        template<typename T> __device__ __host__ __inline__ constexpr matrix_four_type<T>& operator*=(matrix_four_type<T>& a, const matrix_four_type<T> b)
        {
            matrix_four_type<T> c = a * b;
            a = c;
            return a;
        }

        // Compound; matrix_four_type *= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_four_type<T>& operator*=(matrix_four_type<T>& a, const T b)
        {
            matrix_four_type<T> c = a * b;
            a = c;
            return a;
        }

        // Compound; matrix_four_type /= T
        template<typename T> __device__ __host__ __inline__ constexpr matrix_four_type<T>& operator/=(matrix_four_type<T>& a, const T b)
        {
            matrix_four_type<T> c = a / b;
            a = c;
            return a;
        }

        // Comparison; ==
        template<typename T> __device__ __host__ __inline__ constexpr auto operator==(matrix_four_type<T> a, matrix_four_type<T> b)
        {
            return  (a.m11 == b.m11) && (a.m12 == b.m12) && (a.m13 == b.m13) && (a.m14 == b.m14) && 
                    (a.m21 == b.m21) && (a.m22 == b.m22) && (a.m23 == b.m23) && (a.m24 == b.m24) &&
                    (a.m31 == b.m31) && (a.m32 == b.m32) && (a.m33 == b.m33) && (a.m34 == b.m34) &&
                    (a.m41 == b.m41) && (a.m42 == b.m42) && (a.m43 == b.m43) && (a.m44 == b.m44);
        }

        // Comparison; !=
        template<typename T> __device__ __host__ __inline__ constexpr auto operator!=(matrix_four_type<T> a, matrix_four_type<T> b)
        {
            return  (a.m11 != b.m11) || (a.m12 != b.m12) || (a.m13 != b.m13) || (a.m14 != b.m14) || 
                    (a.m21 != b.m21) || (a.m22 != b.m22) || (a.m23 != b.m23) || (a.m24 != b.m24) ||
                    (a.m31 != b.m31) || (a.m32 != b.m32) || (a.m33 != b.m33) || (a.m34 != b.m34) ||
                    (a.m41 != b.m41) || (a.m42 != b.m42) || (a.m43 != b.m43) || (a.m44 != b.m44);
        }

        // Inversion; -
        template<typename T> __device__ __host__ __inline__ constexpr auto operator-(matrix_four_type<T> a)
        {
            return matrix_four_type<T>{ -a.m11, -a.m12, -a.m13, -a.m14,
                                        -a.m21, -a.m22, -a.m23, -a.m24,
                                        -a.m31, -a.m32, -a.m33, -a.m34,
                                        -a.m41, -a.m42, -a.m43, -a.m44 };
        }

        // Inversion; +
        template<typename T> __device__ __host__ __inline__ constexpr auto operator+(matrix_four_type<T> a)
        {
            return matrix_four_type<T>{ +a.m11, +a.m12, +a.m13, +a.m14,
                                        +a.m21, +a.m22, +a.m23, +a.m24,
                                        +a.m31, +a.m32, +a.m33, +a.m34,
                                        +a.m41, +a.m42, +a.m43, +a.m44 };
        }



    // ###############
    // ### Utility ###
    // ###############
        // Probability
            // Random 2-vector
            template<typename T> __device__ auto random_unit_two_vector(curandState* state)
            {
                T u_theta = (curand_uniform(state)-static_cast<T>(0.5)) * static_cast<T>(2) * magik::math::pi;
                using ::sin;
                using ::cos;
                two_vector_type<T> p = { cos(u_theta), sin(u_theta) };
                return p; 
            }

            // Random 3-vector
            template<typename T> __device__ auto random_unit_three_vector(curandState* state)
            {
                using ::sin;
                using ::cos;
                using ::acos;

                T u = static_cast<T>(curand_uniform(state));
                T theta = acos(static_cast<T>(1) - static_cast<T>(2)*u);
                T phi = static_cast<T>(2)*static_cast<T>(magik::math::pi)*curand_uniform(state);

                three_vector_type<T> p;
                p.x = cos(phi) * sin(theta);
                p.y = sin(phi) * sin(theta);
                p.z = cos(theta);
                return p;
            }

            // Z-axis aligned cosine weighted 3-vector
            template<typename T> __device__ auto cosine_weighted_z_alinged_three_vector(curandState* state)
            {
                T u1 = curand_uniform(state);
                T u2 = curand_uniform(state);

                T r = sqrt(static_cast<T>(1.0) - u1);
                T phi = static_cast<T>(2.0 * magik::math::pi) * u2;

                T sin_phi, cos_phi;
                if constexpr (std::is_same_v<T, float>) {
                    sincosf(phi, &sin_phi, &cos_phi);
                } else {
                    sincos(phi, &sin_phi, &cos_phi);
                }

                three_vector_type<T> p;
                p.x = cos_phi * r;
                p.y = sin_phi * r;
                p.z = sqrt(u1);
                
                return p;
            }

            // norm gaussian cdf
            template<typename T> __device__ __host__ auto norm_gaussian_cdf(T mean, T x, T sigma)
            {
                using ::erf;
                using ::sqrt;
                return (static_cast<T>(1)/static_cast<T>(2)) * (static_cast<T>(1) + erf((x - mean) / (sigma * sqrt(static_cast<T>(2)))));
            }

            // triplet32 hash
            template<typename T> __device__ __host__ auto triplet_hash(T x)
            {
                x ^= x >> 17;
                x *= 0xED5AD4BBu;
                x ^= x >> 11;
                x *= 0xAC4C1B51u;
                x ^= x >> 15;
                x *= 0x31848BABu;
                x ^= x >> 14;
                return x;
            }

        // lerp
        template<typename T_value, typename T_t> __device__ __host__ __inline__ constexpr auto lerp(T_value a, T_value b, T_t t)
        {
            return (a * (static_cast<T_t>(1) - t)) + (b * t);
        }

        // map range
        template<typename T> __device__ __host__ __inline__ constexpr auto map_range(T start0, T end0, T start1, T end1, T value)
        {
            return start1 + ((end1 - start1) / (end0 - start0)) * (value - start0);
        }

        // radians to degree
        template<typename T> __device__ __host__ __inline__ constexpr auto radians_to_degree(T radians)
        {
            return radians*(static_cast<T>(180) / static_cast<T>(magik::math::pi));
        }

        // degree to radians
        template<typename T> __device__ __host__ __inline__ constexpr auto degree_to_radians(T degrees)
        {
            return degrees*static_cast<T>(magik::math::pi) / static_cast<T>(180);
        }

        // clamp
        template<typename T> __device__ __host__ __inline__ constexpr auto clamp(T edge0, T edge1, T a)
        {
            if(a < edge0) return edge0;
            if(a > edge1) return edge1;
            return a;
        }
        
        // smooth step
        template<typename T> __device__ __host__ __inline__ constexpr auto smooth_step(T edge0, T edge1, T t)
        {
            T x = magik::math::clamp(static_cast<T>(0), static_cast<T>(1), ((t - edge0) / (edge1 - edge0)));
            return x*x*(static_cast<T>(3)-static_cast<T>(2)*x);
        }

        // smooth ramp
        template<typename T> __device__ __host__ __inline__ constexpr auto smooth_ramp(T amplitude, T exponent, T x, T x0, T range)
        {
            T sign_range = static_cast<T>(1);

            if(range < static_cast<T>(0)) sign_range *= static_cast<T>(-1);

            if((sign_range*x) > (sign_range*(range + x0)))
            {
                return amplitude;
            }
            else if((sign_range*x) < (sign_range*x0))
            {
                return 0.0f;
            }
            else
            {
                using ::pow;
                return amplitude / ( static_cast<T>(1.0) + pow( (x - x0) / (range - (x - x0)) , -exponent ) );
            }
        }

        // fraction
        template<typename T> __device__ __host__ __inline__ constexpr auto fraction(T a)
        {
            using ::modf;
            T _fraction;
            return modf(a, &_fraction);
        }

        // swap
        template<typename T> __device__ __host__ __inline__ constexpr auto swap(T& a, T& b)
        {
            T temp = b;
            b = a;
            a = temp;
        }

        // coordinate transformation
            // spherical to cartesian
            template<typename T> __device__ __host__ __inline__ constexpr auto spherical_to_cartesian(T r, T theta, T phi)
            {
                using ::sin;
                using ::cos;

                return three_vector_type<T>{ r*sin(theta)*cos(phi), r*sin(theta)*sin(phi), r*cos(theta) };
            }

            // cartesian to spherical
            template<typename T> __device__ __host__ __inline__ constexpr auto cartesian_to_spherical(T x, T y, T z)
            {
                using ::sqrt;
                using ::acos;
                using ::atan2;

                T r = sqrt(x*x + y*y + z*z);
                T theta = acos(z/r);
                T phi = atan2(y,x);

                return three_vector_type<T>{r, theta, phi};
            }

            // Z-aligned normal
            template<typename T_vec> __device__ __host__ __inline__ constexpr auto generate_z_aligned_basis_vectors(T_vec omega_i, T_vec normal, T_vec& b_x, T_vec& b_y, T_vec &b_z)
            {
                b_z = normal;
                b_x = (omega_i - (magik::math::vector_dot_product(omega_i, b_z)*b_z)).norm();
                b_y = magik::math::vector_cross_product(b_z, b_x).norm();
            }

            template<typename T_vec> __device__ __host__ __inline__ constexpr auto standard_basis_vector_to_z_aligned(T_vec omega_i, T_vec b_x, T_vec b_y, T_vec b_z)
            {
                return T_vec{ magik::math::vector_dot_product(omega_i, b_x), magik::math::vector_dot_product(omega_i, b_y), magik::math::vector_dot_product(omega_i, b_z) };
            }

            template<typename T_vec> __device__ __host__ __inline__ constexpr auto z_aligned_to_standard_basis_vector(const T_vec rotated_omega_i, T_vec b_x, T_vec b_y, T_vec b_z)
            {
                return rotated_omega_i.x*b_x + rotated_omega_i.y*b_y + rotated_omega_i.z*b_z;
            }

        // Numerical ode step solvers
            // Runge Kutta Fehlberg 45 Step
            template<typename T_function, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto solve_runge_kutta_fehlberg_45_step(T_function f, T_state y0, float& h, float h_max, unsigned int n_max, float abs_tol, float rel_tol, function_args... f_args)
            {
                using ::pow;

                T_state y1, k1, k2, k3, k4, k5, k6, error;
                float h_new = 0.0f, temp_h = h, rms_error = 0.0f, rms_error_safe = 0.0f;

                for(unsigned int i = 0; i < n_max; i++)
                {
                    k1 = f(y0, f_args...);
                    k2 = f(y0 + 1.0f/4.0f*temp_h*k1, f_args...);
                    k3 = f(y0 + 3.0f/32.0f*temp_h*k1 + 9.0f/32.0f*temp_h*k2, f_args...);
                    k4 = f(y0 + 1932.0f/2197.0f*temp_h*k1 - 7200.0f/2197.0f*temp_h*k2 + 7296.0f/2197.0f*temp_h*k3, f_args...);
                    k5 = f(y0 + 439.0f/216.0f*temp_h*k1 - 8.0f*temp_h*k2 + 3680.0f/513.0f*temp_h*k3 - 845.0f/4104.0f*temp_h*k4, f_args...);
                    k6 = f(y0 - 8.0f/27.0f*temp_h*k1 + 2.0f*temp_h*k2 - 3544.0f/2565.0f*temp_h*k3 + 1859.0f/4104.0f*temp_h*k4 - 11.0f/40.0f*temp_h*k5, f_args...);

                    y1 = y0 + 16.0f/135.0f*temp_h*k1 + 6656.0f/12825.0f*temp_h*k3 + 28561.0f/56430.0f*temp_h*k4 - 9.0f/50.0f*temp_h*k5 + 2.0f/55.0f*temp_h*k6;
                    error = -1.0f/360.0f*temp_h*k1 + 128.0f/4275.0f*temp_h*k3 + 2197.0f/75240.0f*temp_h*k4 - 1.0f/50.0f*temp_h*k5 - 2.0f/55.0f*temp_h*k6;

                    rms_error = error.compute_rms_error(error, y0, y1, abs_tol, rel_tol);
                    rms_error_safe = std::max(rms_error, 1e-30f);

                    h_new = 0.9f*temp_h*pow(1.0f / rms_error_safe, 0.2f);
                    h_new = std::min(h_new, h_max);

                    temp_h = h_new;

                    if(rms_error_safe < 1.0f) break;
                }

                h = temp_h;
                return y1;
            }

            // Runge Kutta 4 Step
            template<typename T_function, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto solve_runge_kutta_step(T_function f, T_state y0, float h, function_args... f_args)
            {
                T_state k1, k2, k3, k4;

                k1 = f(y0, f_args...);
                k2 = f(y0 + k1*h/2.0f, f_args...);
                k3 = f(y0 + k2*h/2.0f, f_args...); 
                k4 = f(y0 + h*k3, f_args...);

                return y0 + h/6.0f*(k1 + 2.0f*k2 + 2.0f*k3 + k4);
            }

            // Explicit Euler Step
            template<typename T_function, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto solve_explicit_euler_step(T_function f, T_state y0, float h, function_args... f_args)
            {
                return y0 + h*f(y0, f_args...);
            }

        // Numerical root solvers
            // Bisection
            template<typename T_function, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto root_bisection(T_state& root, T_function f, T_state x_start, T_state x_end, T_state tol, unsigned int max_iter, function_args... f_args)
            {
                using ::abs;
                T_state f_a, f_c;

                f_a = f(x_start, f_args...);
                f_c = f(x_end, f_args...);

                if((static_cast<T_state>(0) > f_a) == (static_cast<T_state>(0) > f_c)) return false;

                T_state a = x_start, b = x_end, c = x_start;

                for(unsigned int i = 0; i < max_iter; i++)
                {
                    c = (a + b) / static_cast<T_state>(2);
                    f_c = f(c, f_args...);

                    if (f_c == static_cast<T_state>(0))
                    {
                        root = c;
                        return true;
                    }

                    if ((f_c < static_cast<T_state>(0)) != (f_a < static_cast<T_state>(0)))
                    {
                        b = c;
                    }
                    else
                    {
                        a = c;
                        f_a = f_c;
                    }

                    if((abs(b-a) <= tol))
                    {
                        root = c;
                        return true;
                    }
                }

                return false;
            }

            // Newton
            template<typename T_function, typename T_derivative, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto root_newton(T_state& root, T_function f, T_derivative df, T_state x_start, T_state tol, T_state eps, unsigned int max_iter, function_args... f_args)
            {
                // Tol is the threshold for accepting a value as the root
                // eps is the minimum number by which we wish to divide by

                using ::abs;
                T_state y0, dy0, x0 = x_start, x_new;

                for(unsigned int i = 0; i < max_iter; i++)
                {
                    y0 = f(x0, f_args...);
                    if(abs(y0) < tol)
                    {
                        root = x0;
                        return true;
                    }

                    dy0 = df(x0, f_args...);
                    if((abs(dy0) < eps) || isnan(dy0)) return false;

                    x_new = x0 - (y0 / dy0);

                    if(abs(x_new - x0) < tol)
                    {
                        root = x_new;
                        return true;
                    }
                    else
                    {
                        x0 = x_new;
                    }
                }

                return false;
            }

            template<typename T_function, typename T_real, typename T_dual, typename... function_args> __device__ __host__ __inline__ constexpr auto root_newton_automatic_differentiation(T_real& root, T_function f, dual_type<T_real, T_dual> x_start, T_real tol, T_real eps, unsigned int max_iter, function_args... f_args)
            {
                using ::abs;
                dual_type<T_real, T_dual> y0, x0 = x_start, x_new;

                for(unsigned int i = 0; i < max_iter; i++)
                {
                    y0 = f(x0, f_args...);
                    if(abs(y0.real) < tol)
                    {
                        root = x0.real;
                        return true;
                    }

                    if((abs(y0.dual) < eps) || isnan(y0.dual)) return false;

                    x_new = x0 - (y0.real / y0.dual);

                    if(abs(x_new.real - x0.real) < tol)
                    {
                        root = x_new.real;
                        return true;
                    }
                    else
                    {
                        x0 = x_new;
                    }
                }

                return false;
            }

            // Brent Dekker
            template<typename T_function, typename T_state, typename... function_args> __device__ __host__ __inline__ constexpr auto root_brent_dekker(T_state& root, T_function f, T_state x_start, T_state x_end, T_state tol, unsigned int max_iter, function_args... f_args)
            {
                /*
                CREDITS; 
                Based on; https://en.wikipedia.org/wiki/Brent%27s_method
                */

                using ::abs;

                T_state a = x_start, b = x_end;
                T_state fa = f(a, f_args...);
                T_state fb = f(b, f_args...);

                if(fa == static_cast<T_state>(0)) { root = a; return true; }
                if(fb == static_cast<T_state>(0)) { root = b; return true; }
                if((fa*fb) > static_cast<T_state>(0)) return false;

                if(abs(fa) < abs(fb))
                {
                    magik::math::swap(fa,fb);
                    magik::math::swap(a,b);
                }

                T_state c = a;
                T_state s;
                T_state d;
                T_state fs = static_cast<T_state>(1); 
                T_state fc = fa;
                T_state g;
                bool m_flag = true, cond_1 = false, cond_2 = false, cond_3 = false, cond_4 = false, cond_5 = false;

                for(unsigned int i = 0; i < max_iter; i++)
                {
                    if(fb == static_cast<T_state>(0) || fs == static_cast<T_state>(0) || abs(b-a) < tol)
                    {
                        root = b;
                        return true;
                    }

                    if((fa != fc) && (fb != fc))
                    {
                        s = ((a*fb*fc)/((fa-fb)*(fa-fc))) + ((b*fa*fc)/((fb-fa)*(fb-fc))) + ((c*fa*fb)/((fc-fa)*(fc-fb)));
                    }
                    else
                    {
                        s = b-fb*((b-a)/(fb-fa));
                    }

                    g = ((static_cast<T_state>(3)*a+b) / static_cast<T_state>(4));
                    cond_1 = (s < g && s < b) || (s > g && s > b);
                    cond_2 = m_flag && (abs(s-b) >= (abs(b-c)/static_cast<T_state>(2)));
                    cond_3 = !m_flag && (abs(s-b) >= (abs(c-d)/static_cast<T_state>(2)));
                    cond_4 = m_flag && (abs(b-c) < abs(tol));
                    cond_5 = !m_flag && (abs(c-d) < abs(tol));

                    if(cond_1 || cond_2 || cond_3 || cond_4 || cond_5)
                    {
                        s = (a+b)/static_cast<T_state>(2);
                        m_flag = true;
                    }
                    else
                    {
                        m_flag = false;
                    }

                    fs = f(s, f_args...);
                    d = c;
                    c = b;
                    fc = fb;

                    if(fa*fs < static_cast<T_state>(0))
                    {
                        b = s;
                        fb = fs;
                    }
                    else
                    {
                        a = s;
                        fa = fs;
                    }

                    if(abs(fa) < abs(fb))
                    {
                        magik::math::swap(fa,fb);
                        magik::math::swap(a,b);
                    }
                }

                return false;
            }

        // Noise
            // 2D Cell worley (With octaves)

            // 3D Cell worley (With octaves)

            // Bokeh (2D, 3D, 4D)

        // Physics
            // Spectral power distributions
            template<typename T> __device__ __host__ __inline__ constexpr auto gaussian_distribution(T x, T offset, T width, T scale)
            {
                using ::exp;
                return exp(static_cast<T>(-0.5)*(((x-offset) * (x-offset))/(width*width)))*scale;
            }

            template<typename T> __device__ __host__ __inline__ constexpr auto evaluate_red_neon_spectrum(T wavelength)
            {
                T f0 = gaussian_distribution(wavelength, static_cast<T>(532.5), static_cast<T>(1.41421356237), static_cast<T>(13.0));
                T f1 = gaussian_distribution(wavelength, static_cast<T>(541.5), static_cast<T>(3.16227766017), static_cast<T>(28.0));
                T f2 = gaussian_distribution(wavelength, static_cast<T>(595.5), static_cast<T>(2.2360679775), static_cast<T>(70.0));
                T f3 = gaussian_distribution(wavelength, static_cast<T>(607.5), static_cast<T>(4.472135955), static_cast<T>(110.0));
                T f4 = gaussian_distribution(wavelength, static_cast<T>(623.5), static_cast<T>(3.74165738677), static_cast<T>(120.0));
                T f5 = gaussian_distribution(wavelength, static_cast<T>(635.5), static_cast<T>(2.2360679775), static_cast<T>(55.0));
                T f6 = gaussian_distribution(wavelength, static_cast<T>(647.5), static_cast<T>(8.36660026534), static_cast<T>(90.0));
                T f7 = gaussian_distribution(wavelength, static_cast<T>(668.5), static_cast<T>(3.16227766017), static_cast<T>(45.0));
                T f8 = gaussian_distribution(wavelength, static_cast<T>(595.5), static_cast<T>(7.07106781187), static_cast<T>(25.0));
                T f9 = gaussian_distribution(wavelength, static_cast<T>(660.5), static_cast<T>(1.73205080757), static_cast<T>(25.0));
                T f10 = gaussian_distribution(wavelength, static_cast<T>(597.5), static_cast<T>(1.73205080757), static_cast<T>(80.0));
                T f11 = gaussian_distribution(wavelength, static_cast<T>(657.0), static_cast<T>(1.0), static_cast<T>(20.0));
                T f12 = gaussian_distribution(wavelength, static_cast<T>(628.0), static_cast<T>(1.41421356237), static_cast<T>(40.0));
                return f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9 + f10 + f11 + f12;
            }

            template<typename T> __device__ __host__ __inline__ constexpr auto evaluate_sodium_vapor_lamp_spectrum(T wavelength)
            {
                T f0 = gaussian_distribution(wavelength, static_cast<T>(600.0), static_cast<T>(70.7106781187), static_cast<T>(1.0));
                T f1 = gaussian_distribution(wavelength, static_cast<T>(495.4), static_cast<T>(0.2), static_cast<T>(1.0));
                T f2 = gaussian_distribution(wavelength, static_cast<T>(500.55), static_cast<T>(0.836660026534), static_cast<T>(1.2));
                T f3 = gaussian_distribution(wavelength, static_cast<T>(572.0), static_cast<T>(0.547722557505), static_cast<T>(6.0));
                T f4 = gaussian_distribution(wavelength, static_cast<T>(573.5), static_cast<T>(2), static_cast<T>(2.4));
                T f5 = gaussian_distribution(wavelength, static_cast<T>(589.5), static_cast<T>(0.774596669241), static_cast<T>(1.3));
                T f6 = gaussian_distribution(wavelength, static_cast<T>(596.0), static_cast<T>(0.707106781187), static_cast<T>(134.0));
                T f7 = gaussian_distribution(wavelength, static_cast<T>(592.9), static_cast<T>(0.707106781187), static_cast<T>(137.5));
                T f8 = gaussian_distribution(wavelength, static_cast<T>(594.45), static_cast<T>(0.92736184955), static_cast<T>(174.0));
                T f9 = gaussian_distribution(wavelength, static_cast<T>(597.0), static_cast<T>(1.58113883008), static_cast<T>(10.0));
                T f10 = gaussian_distribution(wavelength, static_cast<T>(621.0), static_cast<T>(1.0), static_cast<T>(2.0));
                T f11 = gaussian_distribution(wavelength, static_cast<T>(646.5), static_cast<T>(0.4472135955), static_cast<T>(4.0));
                T f12 = gaussian_distribution(wavelength, static_cast<T>(648.0), static_cast<T>(1.0), static_cast<T>(1.0));
                T f13 = gaussian_distribution(wavelength, static_cast<T>(657.5), static_cast<T>(1.0), static_cast<T>(1.0));
                T f14 = gaussian_distribution(wavelength, static_cast<T>(709.3), static_cast<T>(1.0), static_cast<T>(1.9));
                return f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9 + f10 + f11 + f12 + f13 + f14;
            }

            template<typename T> __device__ __host__ __inline__ constexpr auto evaluate_halophosphate_type_fluorescent_bulb_spectrum(T wavelength)
            {
                T f0 = gaussian_distribution(wavelength, static_cast<T>(585.0), static_cast<T>(28.2842712475), static_cast<T>(125.0));
                T f1 = gaussian_distribution(wavelength, static_cast<T>(615.0), static_cast<T>(70.7106781187), static_cast<T>(23.0));
                T f2 = gaussian_distribution(wavelength, static_cast<T>(500.0), static_cast<T>(94.8683298051), static_cast<T>(5.0));
                T f3 = gaussian_distribution(wavelength, static_cast<T>(490.0), static_cast<T>(28.2842712475), static_cast<T>(12.0));
                T f4 = gaussian_distribution(wavelength, static_cast<T>(400.0), static_cast<T>(47.9583152331), static_cast<T>(6.0));
                T f5 = gaussian_distribution(wavelength, static_cast<T>(364.3), static_cast<T>(1.41421356237), static_cast<T>(7.0));
                T f6 = gaussian_distribution(wavelength, static_cast<T>(404.0), static_cast<T>(1.0), static_cast<T>(34.0));
                T f7 = gaussian_distribution(wavelength, static_cast<T>(435.0), static_cast<T>(1.0), static_cast<T>(233.5));
                T f8 = gaussian_distribution(wavelength, static_cast<T>(545.5), static_cast<T>(1.22474487139), static_cast<T>(185.0));
                T f9 = gaussian_distribution(wavelength, static_cast<T>(576.0), static_cast<T>(0.547722557505), static_cast<T>(45.0));
                T f10 = gaussian_distribution(wavelength, static_cast<T>(578.0), static_cast<T>(0.547722557505), static_cast<T>(37.0));
                return (f0 + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8 + f9 + f10);
            }

            template<typename T> __device__ __host__ __inline__ constexpr auto sample_plancks_law(T wavelength_nm, T temperature)
            {
                using ::exp;

                if(temperature <= static_cast<T>(0)) return static_cast<T>(0);

                T wavelength_metre = wavelength_nm * static_cast<T>(1e-9);

                constexpr T term_0 = static_cast<T>(magik::math::planck_constant)*static_cast<T>(magik::math::speed_of_light);
                constexpr T term_1 = static_cast<T>(2)*term_0*static_cast<T>(magik::math::speed_of_light);

                T term_2 = wavelength_metre*wavelength_metre*wavelength_metre*wavelength_metre*wavelength_metre;
                T term_3 = exp(term_0 / (wavelength_metre*magik::math::boltzmann_constant*temperature)) - static_cast<T>(1);

                return (term_1/term_2)*(static_cast<T>(1)/term_3);
            }

        // Fourier Transform
}
