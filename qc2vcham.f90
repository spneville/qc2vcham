!######################################################################
! qc2vcham: a simple program to parse the output of a quantum
!           chemistry calculation, extract the parameters of a LVC
!           Hamiltonian, and output these in a format that can be
!           used directly with the VCHFIT and MCTDH codes.
!######################################################################

program qc2vcham

  use constants
  use global
  use ioqc

  implicit none

  integer :: i
  
!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
  call initialise

!----------------------------------------------------------------------
! Read the command line arguments
!----------------------------------------------------------------------
  call rdinput

!----------------------------------------------------------------------
! Determine the type of quantum chemisty calculations used for the
! frequency and excited state calculations
!----------------------------------------------------------------------
  call freqtype
  call qctype

!----------------------------------------------------------------------
! Determine the system dimensions from the quantum chemistry output
! files
!----------------------------------------------------------------------
  call getdim

!----------------------------------------------------------------------
! Reset nsta if the requested no. states is less than the number in
! the quantum chemistry calculation
!----------------------------------------------------------------------
  if (smax.lt.nsta) nsta=smax
  
!----------------------------------------------------------------------
! Allocate arrays
!----------------------------------------------------------------------
  call alloc

!----------------------------------------------------------------------
! Read the frequency file: normal modes and reference geometry
!----------------------------------------------------------------------
  call rdfreqfile

!----------------------------------------------------------------------
! Create the transformation matrices
!----------------------------------------------------------------------
  call nm2xmat

!----------------------------------------------------------------------
! Read the energies, Cartesian gradients and NACTs
!----------------------------------------------------------------------
  call rdener
  if (lgrad) call rdgrad
  if (lnact) call rdnact
  
!----------------------------------------------------------------------
! If needed, read the dipole matrix elements
!----------------------------------------------------------------------
  if (hml) call rddip
  
!----------------------------------------------------------------------
! Transform the gradient and NACT vectors
!----------------------------------------------------------------------
  if (lgrad) call transgrad
  if (lnact) call transnact

!----------------------------------------------------------------------
! If needed, determine approximate lambda values from the numerical
! 2nd-derivatives of the squared adiabatic energy differences
!----------------------------------------------------------------------
  if (laprxlambda) call approx_lambda
  
!----------------------------------------------------------------------
! If requested, convert the LVC parameters to a.u.
!----------------------------------------------------------------------
  if (outau) call par2au

!----------------------------------------------------------------------
! Write the output files:
!
! (1) VCHFIT guess file
! (2) MCTDH operator file
! (3) LVC data file for use with the PLTLVC program
!----------------------------------------------------------------------
  call wrguess
  call wroper
  call wrdatfile

!----------------------------------------------------------------------
! Write some information about the LVC Hamiltonian to the log file
!----------------------------------------------------------------------
  call wrlvcinfo

!----------------------------------------------------------------------
! Finalisation and deallocataion
!----------------------------------------------------------------------
  call finalise

contains

!######################################################################

  subroutine initialise
    
    use channels
    use iomod

    implicit none

!----------------------------------------------------------------------
! Open the logfile
!----------------------------------------------------------------------
    call freeunit(ilog)
    open(ilog,file='qc2vcham.log',form='formatted',status='unknown')

!----------------------------------------------------------------------
! Logical flags controling what is to be read from the excited state
! calculation output
!----------------------------------------------------------------------
    lgrad=.false.
    lnact=.false.

    return

  end subroutine initialise

!######################################################################

  subroutine rdinput

    use constants
    use global
    use iomod
    use channels

    implicit none

    character(len=120) :: string

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    ! Name of the frequency file
    freqfile=''

    ! Quantum chemistry file or diractory name
    qcfile=''

    ! Flag to control whether or not the LVC parameter values are to
    ! be output in a.u.
    outau=.false.

    ! H_ML (Interaction with an external field)
    hml=.false.
    ! Central frequency (eV)
    omega=-999.0d0
    ! Centre of the peak (fs)
    t0=-999.0d0
    ! FWHM (fs)
    sigma=-999.0d0
    ! Peak intensity (W/cm^2)
    I0=-999.0d0

    ! Approximate lambda calculation
    laprxlambda=.false.

    ! No. states to consider
    smax=999

    ! Deuteration
    ldeuterate=.false.

    ! DRT no. to parse for a Columbus calculation
    idrt=1
    
!----------------------------------------------------------------------
! If no arguments have been given, print the input options to the
! screen and then quit
!----------------------------------------------------------------------
    if (iargc().eq.0) call wrhelp
    
!----------------------------------------------------------------------
! Determine whether the input is given via an input file or the
! command line
!----------------------------------------------------------------------
    call getarg(1,string)
    
    if (string(1:1).eq.'-') then
       inpfile=.false.
    else
       inpfile=.true.
    endif

!----------------------------------------------------------------------
! Read the input
!----------------------------------------------------------------------
    if (inpfile) then
       call rdinput_inpfile
    else
       call rdinput_cmdline
    end if

!----------------------------------------------------------------------
! Make sure that all the required information has been given
!----------------------------------------------------------------------
    if (freqfile.eq.'') then
       errmsg="The frequency file has not been given"
       call error_control
    endif

    if (qcfile(1).eq.'') then
       errmsg="The quantum chemisty filename/directory has not &
            been given"
       call error_control
    endif

!----------------------------------------------------------------------
! Output some information to the log file
!----------------------------------------------------------------------
    write(ilog,'(/,2(2x,a))') "Frequency file:",trim(freqfile)
    write(ilog,'(/,2(2x,a))') "Quantum chemistry filename/directoty:",&
         trim(qcfile(1))

    return
 
  end subroutine rdinput

!######################################################################

  subroutine rdinput_cmdline

    use constants
    use global
    use iomod
    use channels

    implicit none

    integer            :: n,k
    character(len=120) :: string1,string2
    
!----------------------------------------------------------------------
! Read the command line arguments
!----------------------------------------------------------------------
    n=0
5   continue
    
    n=n+1
    call getarg(n,string1)
       
    if (string1.eq.'-h') then
       call wrhelp
    else if (string1.eq.'-d') then
       n=n+1
       call getarg(n,qcfile(1))
       k=1
10     continue
       call getarg(n+1,string2)
       if (string2(1:1).ne.'-'.and.n.ne.iargc()) then
          n=n+1
          k=k+1
          qcfile(k)=string2
          goto 10
       endif
    else if (string1.eq.'-f') then
       n=n+1
       call getarg(n,freqfile)
    else if (string1.eq.'-au') then
       outau=.true.
    else if (string1.eq.'-hml') then
       hml=.true.
       n=n+1
       call getarg(n,string2)
       read(string2,*) omega
       n=n+1
       call getarg(n,string2)
       read(string2,*) t0
       n=n+1
       call getarg(n,string2)
       read(string2,*) sigma
       n=n+1
       call getarg(n,string2)
       read(string2,*) I0
    else if (string1.eq.'-smax') then
       n=n+1
       call getarg(n,string2)
       read(string2,*) smax
    else if (string1.eq.'-deuterate') then
       ldeuterate=.true.
    else if (string1.eq.'-drt') then
       n=n+1
       call getarg(n,string2)
       read(string2,*) idrt
    else
       errmsg='Unknown keyword: '//trim(string1)
       call error_control
    endif

    if (n.lt.iargc()) goto 5
    
    return
    
  end subroutine rdinput_cmdline

!######################################################################

  subroutine rdinput_inpfile

    use constants
    use global
    use iomod
    use channels
    use parsemod
    
    implicit none

    integer            :: i,n,k
    character(len=120) :: filename
    
!----------------------------------------------------------------------
! Get the name of the input file
!----------------------------------------------------------------------
    call getarg(1,filename)

    if (index(filename,'.inp').eq.0) filename=trim(filename)//'.inp'

!----------------------------------------------------------------------
! Open the input file
!----------------------------------------------------------------------
    call freeunit(iin)
    open(iin,file=filename,form='formatted',status='old')
    
!----------------------------------------------------------------------    
! Read the input file
!----------------------------------------------------------------------
5   continue
    call rdinp(iin)

    i=0
    if (.not.lend) then

10     continue
       i=i+1

       if (keyword(i).eq.'freqfile') then
          if (keyword(i+1).eq.'=') then
             i=i+2
             freqfile=keyword(i)
          else
             goto 100
          endif

       else if (keyword(i).eq.'qcfiles') then
          n=0
15        continue
          call rdinp(iin)
          if (keyword(1).ne.'end-qcfiles') then
             n=n+1
             qcfile(n)=keyword(1)
             goto 15
          endif

       else if (keyword(i).eq.'hml') then
          hml=.true.
          if (keyword(i+1).eq.'=') then
             i=i+2
             read(keyword(i),*) omega
             if (keyword(i+1).ne.',') then
                errmsg='The t0 argument has not been given with &
                     the hml keyword'
                call error_control
             endif
             i=i+2
             read(keyword(i),*) t0
             if (keyword(i+1).ne.',') then
                errmsg='The sigma argument has not been given with &
                     the hml keyword'
                call error_control
             endif
             i=i+2
             read(keyword(i),*) sigma
             if (keyword(i+1).ne.',') then
                errmsg='The I0 argument has not been given with &
                     the hml keyword'
                call error_control
             endif
             i=i+2
             read(keyword(i),*) I0
          else
             goto 100
          endif

       else if (keyword(i).eq.'au') then
          outau=.true.

       else if (keyword(i).eq.'lambda_files') then
          laprxlambda=.true.
          ! Determine the no. files and allocate arrays
          !n=nlambdafiles(filename)
          !allocate(lambdafile(n))
          ! Read the names of the files
          nlambdafiles=0
20        call rdinp(iin)
          if (keyword(1).ne.'end-lambda_files') then
             nlambdafiles=nlambdafiles+1
             lambdafile(nlambdafiles)=keyword(1)
             goto 20
          endif

       else if (keyword(i).eq.'smax') then
          if (keyword(i+1).eq.'=') then
             i=i+2
             read(keyword(i),*) smax
          else
             goto 100
          endif

       else if (keyword(i).eq.'deuterate') then
          ldeuterate=.true.

       else if (keyword(i).eq.'drt') then
          if (keyword(i+1).eq.'=') then
             i=i+2
             read(keyword(i),*) idrt
          else
             goto 100
          endif
          
       else
          ! Exit if the keyword is not recognised
          errmsg='Unknown keyword: '//trim(keyword(i))
          call error_control
       endif

       ! If there are more keywords to be read on the current line,
       ! then read them, else read the next line
       if (i.lt.inkw) then
          goto 10
       else
          goto 5
       endif
       
       ! Exit if a required argument has not been given with a keyword
100    continue
       errmsg='No argument given with the keyword '//trim(keyword(i))
       call error_control
       
    endif

!----------------------------------------------------------------------
! Close the input file
!----------------------------------------------------------------------
    close(iin)
    
    return
    
  end subroutine rdinput_inpfile

!######################################################################

  subroutine wrhelp

    implicit none

    integer :: i

!----------------------------------------------------------------------
! Write the input options to screen, then quit
!----------------------------------------------------------------------
    ! Purpose
    write(6,'(/,25a)') ('-',i=1,25)
    write(6,'(a)') 'Purpose'
    write(6,'(25a)') ('-',i=1,25)
    write(6,'(a)') 'Calculates the parameters of the LVC &
         Hamiltonian from quantum chemistry output.'

    ! Usage
    write(6,'(/,25a)') ('-',i=1,25)
    write(6,'(a)') 'Usage'
    write(6,'(25a)') ('-',i=1,25)
    write(6,'(a)') 'qcvcham -f -d (-hml -au -smax -deuterate -drt)'
    
    ! Options
    write(6,'(/,25a)') ('-',i=1,25)
    write(6,'(a)')   'Options'
    write(6,'(25a)') ('-',i=1,25)
    write(6,'(a)')     '-f FREQFILE            : &
         The normal modes and frequencies are read from FREQFILE'
    write(6,'(a)')     '-d QCFILE              : &
         The quantum chemisty output is contained in the &
         file or directory QCFILE'
    write(6,'(a,4(/,25x,a))') '-hml OMEGA T0 SIGMA I0 : &
         The zeroth-order light-matter interaction Hamiltonian is &
         to also be calculated',&
         'The central frequency is OMEGA (eV)',&
         'The pulse is centred at time T0 (fs)',&
         'The FWHM of the pulse is SIGMA (fs)',&
         'The peak intensity of the pulse is I0 (W/cm^2)'
    write(6,'(a)')     '-au                    : &
         The MCTDH operator file is the be written in atomic units'
    write(6,'(a)')     '-smax N                : &
         Only include the first N states in the LVC Hamiltonian'
    write(6,'(a)')     '-deuterate             : &
         Replace hydrogen atoms with deuterium atoms'
    write(6,'(a,/,25x,a)')     '-drt N                 : &
         When parsing the output of a Columbus calculation, the &
         results will be read for DRT number N',&
         'The default value is N=1'
    
    
    write(6,'(/)')

    stop
    
    return
    
  end subroutine wrhelp
    
!######################################################################

  subroutine alloc

    use global

    implicit none

    ! Vertical excitation energies
    allocate(ener(nsta))
    ener=0.0d0
    
    ! Energy gradients in Cartesians
    allocate(grad(ncoo,nsta))
    grad=0.0d0

    ! NACTs in Cartesians
    allocate(nact(ncoo,nsta,nsta))
    nact=0.0d0

    ! Energy gradients in normal modes
    allocate(kappa(nmodes,nsta))
    kappa=0.0d0

    ! NACTs in normal modes
    allocate(lambda(nmodes,nsta,nsta))
    lambda=0.0d0

    ! Atomic masses
    allocate(mass(ncoo))
    mass=0.0d0

    ! Reference coordinates
    allocate(xcoo0(ncoo))
    xcoo0=0.0d0

    ! Atomic numbers
    allocate(atnum(natm))
    atnum=0

    ! Atom labels
    allocate(atlbl(natm))
    atlbl=''

    ! Normal mode labels
    allocate(nmlab(nmodes))
    nmlab=''

    ! Normal mode frequencies
    allocate(freq(nmodes))
    freq=0.0d0

    ! Transformation matrices
    allocate(nmcoo(ncoo,nmodes))
    allocate(coonm(nmodes,ncoo))
    nmcoo=0.0d0
    coonm=0.0d0

    ! Dipole matrix
    allocate(dipole(3,nsta,nsta))
    dipole=0.0d0

    return

  end subroutine alloc

!######################################################################

  subroutine transgrad

    use constants
    use global

    implicit none

    integer                       :: s
    real(d), dimension(ncoo,nsta) :: tmpvec

!-----------------------------------------------------------------------
! nmcoo transforms from angstrom to Q, and the gradients have been
! read in a.u.
! Hence, we rescale the gradients here
!-----------------------------------------------------------------------
    tmpvec=grad*ang2bohr

!-----------------------------------------------------------------------
! Transform the gradients to the normal mode basis
!-----------------------------------------------------------------------
    do s=1,nsta
       kappa(:,s)=matmul(transpose(nmcoo),tmpvec(:,s))
    enddo

!-----------------------------------------------------------------------
! Convert to eV
!-----------------------------------------------------------------------
    kappa=kappa*eh2ev

    return

  end subroutine transgrad

!######################################################################

  subroutine transnact

    use constants
    use global

    implicit none

    integer                            :: s1,s2
    real(d), dimension(ncoo,nsta,nsta) :: tmpvec

!-----------------------------------------------------------------------
! coonm transforms from angstrom to Q, and the NACTs have been
! read in a.u.
! Hence, we rescale the NACTs here
!-----------------------------------------------------------------------
    tmpvec=nact*ang2bohr

!-----------------------------------------------------------------------
! Transform the NACTs to the normal mode basis
!-----------------------------------------------------------------------
    do s1=1,nsta
       do s2=1,nsta
          lambda(:,s1,s2)=matmul(transpose(nmcoo),tmpvec(:,s1,s2))
       enddo
    enddo

!-----------------------------------------------------------------------
! Convert to eV
!-----------------------------------------------------------------------
    lambda=lambda*eh2ev

    return

  end subroutine transnact

!######################################################################

  subroutine par2au

    use global

    implicit none

!----------------------------------------------------------------------
! Convert the LVC parameter values from eV to a.u.
!----------------------------------------------------------------------
    freq=freq/eh2ev
    ener=ener/eh2ev
    kappa=kappa/eh2ev
    lambda=lambda/eh2ev

    return

  end subroutine par2au

!######################################################################

  subroutine wrguess
    
    use constants
    use global
    use iomod

    implicit none

    integer            :: unit,s,s1,s2,m
    real(d), parameter :: thrsh=5e-4
!----------------------------------------------------------------------
! Open the vchfit guess file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file='guess.dat',form='formatted',status='unknown')

!----------------------------------------------------------------------
! Write the 1st-order intrastate coupling terms (kappa)
!----------------------------------------------------------------------
    write(unit,'(a)') '# 1st-order intrastate coupling terms (kappa)'
    do m=1,nmodes
       do s=1,nsta
          if (abs(kappa(m,s)).lt.thrsh) cycle
          write(unit,'(a5,2(x,i2),x,a2,F8.5)') &
               'kappa',m,s,'= ',kappa(m,s)
       enddo
    enddo

!----------------------------------------------------------------------
! Write the 1st-order interstate coupling terms (lambda)
!----------------------------------------------------------------------
    write(unit,'(a)') '# 1st-order interstate coupling terms (lambda)'
    do m=1,nmodes
       do s1=1,nsta-1
          do s2=s1+1,nsta
             if (abs(lambda(m,s1,s2)).lt.thrsh) cycle
             write(unit,'(a6,3(x,i2),x,a2,F8.5)') &
                  'lambda',m,s1,s2,'= ',lambda(m,s1,s2)
          enddo
       enddo
    enddo

!----------------------------------------------------------------------
! Close the vchfit guess file
!----------------------------------------------------------------------
    close(unit)

    return

  end subroutine wrguess

!######################################################################

  subroutine wroper

    use constants
    use global
    use iomod

    implicit none

    integer                        :: unit,m,s,s1,s2,i,j,k,c,nl,&
                                      ncurr,fel
    real(d), parameter             :: thrsh=5e-4
    character(len=2)               :: am,as,as1,as2,afel,aft
    character(len=5)               :: aunit
    character(len=90)              :: string
    character(len=3)               :: amode
    character(len=8)               :: atmp
    character(len=1), dimension(3) :: acomp

!----------------------------------------------------------------------
! Get the unit label
!----------------------------------------------------------------------
    if (outau) then
       aunit='     '
    else
       aunit=' , ev'
    endif

!----------------------------------------------------------------------
! Open the MCTDH operator file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file='lvc.op',form='formatted',status='unknown')

!----------------------------------------------------------------------
! Index of the electronic DOF
!----------------------------------------------------------------------
    fel=nmodes+1
    write(afel,'(i2)') fel

!----------------------------------------------------------------------
! Index of the Time DOF
!----------------------------------------------------------------------
    write(aft,'(i2)') fel+1

!----------------------------------------------------------------------
! Cartesian axis labels
!----------------------------------------------------------------------
    acomp=(/ 'x' , 'y' , 'z' /)
    
!----------------------------------------------------------------------
! Write the op_define section
!----------------------------------------------------------------------
    write(unit,'(a)') 'op_define-section'
    write(unit,'(a)') 'title'
    write(unit,'(a)') 'MCTDH operator file created by qc2vcham'
    write(unit,'(a)') 'end-title'
    write(unit,'(a)') 'end-op_define-section'

!----------------------------------------------------------------------
! Write the parameter section
!----------------------------------------------------------------------
    ! Starting line
    write(unit,'(/,a)') 'parameter-section'

    ! Frequencies
    write(unit,'(/,a)') '# Frequencies'
    do m=1,nmodes
       write(am,'(i2)') m
       write(unit,'(a,F9.6,a)') &
            'omega_'//adjustl(am)//' =',freq(m),aunit
    enddo

    ! Energies
    write(unit,'(/,a)') '# Energies'
    do s=1,nsta
       write(as,'(i2)') s
       write(unit,'(a,F9.6,a)') &
            'E'//adjustl(as)//' = ',ener(s),aunit
    enddo
    
    ! 1st-order intrastate coupling constants (kappa)
    write(unit,'(/,a)') '# 1st-order intrastate coupling &
         constants (kappa)'
    do s=1,nsta
       write(as,'(i2)') s
       do m=1,nmodes
          if (abs(kappa(m,s)).lt.thrsh) cycle
          write(am,'(i2)') m
          write(unit,'(a,F9.6,a)') 'kappa'//trim(adjustl(as))&
               //'_'//adjustl(am)//' = ',kappa(m,s),aunit
       enddo
    enddo

    ! 1st-order intrastate coupling constants (lambda)
    write(unit,'(/,a)') '# 1st-order interstate coupling &
         constants (lambda)'
    do s1=1,nsta-1
       write(as1,'(i2)') s1
       do s2=s1+1,nsta
          write(as2,'(i2)') s2
          do m=1,nmodes
             if (abs(lambda(m,s1,s2)).lt.thrsh) cycle
             write(am,'(i2)') m
             write(unit,'(a,F9.6,a)') 'lambda'//trim(adjustl(as1))&
               //'_'//trim(adjustl(as2))//'_'//adjustl(am)//&
               ' = ',lambda(m,s1,s2),aunit
          enddo
       enddo
    enddo

    ! Dipole matrix elements
    if (hml) then
       write(unit,'(/,a)') '# Dipole matrix elements'
       do c=1,3
          do s1=1,nsta
             write(as1,'(i2)') s1
             do s2=s1,nsta
                write(as2,'(i2)') s2
                if (abs(dipole(c,s1,s2)).lt.thrsh) cycle
                write(unit,'(a,F9.6)') 'dip'//acomp(c)&
                     //trim(adjustl(as1))//trim(adjustl(as2))&
                     //' = ',dipole(c,s1,s2)
             enddo
          enddo
       enddo          
    endif

    ! Pulse parameters
    if (hml) then
       write(unit,'(/,a)') '# Pulse parameters'
       write(unit,'(a)') 'A = 2.7726'
       write(unit,'(a)') 'B = A/PI'
       write(unit,'(a)') 'C = B^0.5'
       write(unit,'(a,F5.2,a)') 'width = ',sigma,' , fs'
       write(unit,'(a,F5.2,a)') 'freq = ',omega,aunit
       write(unit,'(a,F5.2,a)') 't0 = ',t0,' , fs'
       write(unit,'(a,F20.3,a)') 'I0 = ',I0,' , winvcm2'
       write(unit,'(a)') 's = I0*width/C'
    endif

    ! Finishing line
    write(unit,'(/,a)') 'end-parameter-section'

!----------------------------------------------------------------------
! Write the labels section
!----------------------------------------------------------------------
    if (hml) then
       
       ! Starting line
       write(unit,'(/,a)') 'LABELS-SECTION'

       ! Pulse functions
       write(unit,'(/,a)') 'pulse = gauss[A/width^2,t0]'
       write(unit,'(a)') 'cosom = cos[freq,t0]'
       write(unit,'(a)') 'stepf = step[t0-1.25*width]'
       write(unit,'(a)') 'stepr = rstep[t0+1.25*width]'

       ! Finishing line
       write(unit,'(/,a)') 'end-labels-section'
    
    endif

!----------------------------------------------------------------------
! Write the Hamiltonian section
!----------------------------------------------------------------------
    ! Starting line
    write(unit,'(/,a)') 'hamiltonian-section'

    ! Modes section
    write(unit,'(/,38a)') ('-',i=1,38)
    m=0    
    if (hml) then
       nl=ceiling((real(nmodes+2))/10.0d0)
    else
       nl=ceiling((real(nmodes+1))/10.0d0)
    endif
    do i=1,nl
       if (hml) then
          ncurr=min(10,nmodes+2-10*(i-1))
       else
          ncurr=min(10,nmodes+1-10*(i-1))
       endif
       string='modes|'
       do k=1,ncurr
          m=m+1
          if (m.lt.nmodes+1) then
             write(amode,'(i3)') m
             write(atmp,'(a)') ' v'//adjustl(amode)//' '
             if (m.lt.10) then
                string=trim(string)//trim(atmp)//'  |'
             else
                string=trim(string)//trim(atmp)//' |'
             endif
          else
             if (m.eq.nmodes+1) then
                string=trim(string)//' el'
             else
                string=trim(string)//'  | Time'
             endif
          endif
       enddo
       write(unit,'(a)') trim(string)
    enddo
    write(unit,'(38a)') ('-',i=1,38)

    ! Kinetic energy operator
    write(unit,'(/,a)') '# Kinetic energy'
    do m=1,nmodes
       write(am,'(i2)') m
       write(unit,'(a)') &
            'omega_'//adjustl(am)//'  |'//adjustl(am)//'  KE'
    enddo

    ! Zeroth-order potential: VEEs
    write(unit,'(/,a)') '# Zeroth-order potential: VEEs'
    do s=1,nsta
       write(as,'(i2)') s
       write(unit,'(a)') &
            'E'//adjustl(as)//'  |'//adjustl(afel)&
            //'  S'//trim(adjustl(as))//'&'//trim(adjustl(as))
    enddo

    ! Zeroth-order potential: Harmonic oscillators
    write(unit,'(/,a)') '# Zeroth-order potential: &
         Harmonic oscillators'
    do m=1,nmodes
       write(am,'(i2)') m
       write(unit,'(a)') &
            '0.5*omega_'//adjustl(am)//'  |'//adjustl(am)//'  q^2'
    enddo

    ! 1st-order intrastate coupling terms (kappa)
    write(unit,'(/,a)') '# 1st-order intrastate coupling &
         constants (kappa)'
    do m=1,nmodes
       write(am,'(i2)') m
       do s=1,nsta
          if (abs(kappa(m,s)).lt.thrsh) cycle
          write(as,'(i2)') s
          write(unit,'(a)') 'kappa'//trim(adjustl(as))&
               //'_'//adjustl(am)&
               //'  |'//adjustl(am)//'  q'//'  |'//adjustl(afel)&
               //'  S'//trim(adjustl(as))//'&'//trim(adjustl(as))
       enddo
    enddo

    ! 1st-order interstate coupling terms (lambda)
    write(unit,'(/,a)') '# 1st-order interstate coupling &
         constants (lambda)'
    do m=1,nmodes
       write(am,'(i2)') m
       do s1=1,nsta-1
          write(as1,'(i2)') s1
          do s2=s1+1,nsta
             if (abs(lambda(m,s1,s2)).lt.thrsh) cycle
             write(as2,'(i2)') s2
             write(unit,'(a)') 'lambda'//trim(adjustl(as1)) &
                  //'_'//trim(adjustl(as2))//'_'//adjustl(am) &
                  //'  |'//adjustl(am)//'  q'//'  |'//adjustl(afel)&
                  //'  S'//trim(adjustl(as1))//'&'//trim(adjustl(as2))
          enddo
       enddo
    enddo

    ! Light-molecule interaction (H_ML)
    if (hml) then
       write(unit,'(/,a)') '# Light-molecule interaction (H_ML)'
       do c=1,3
          do s1=1,nsta
             write(as1,'(i2)') s1
             do s2=s1,nsta
                write(as2,'(i2)') s2
                if (abs(dipole(c,s1,s2)).lt.thrsh) cycle
                write(unit,'(a)') '-dip'//acomp(c)&
                     //trim(adjustl(as1))//trim(adjustl(as2))&
                     //'*s*C/width'//'  |'//adjustl(afel)&
                     //'  S'//trim(adjustl(as1))//'&'&
                     //trim(adjustl(as2))//'  |'//adjustl(aft)&
                     //'  cosom*pulse*stepf*stepr'
             enddo
          enddo
       enddo
    endif

    ! Finishing line
    write(unit,'(/,a)') 'end-hamiltonian-section'

!----------------------------------------------------------------------
! End line
!----------------------------------------------------------------------
    write(unit,'(/,a)') 'end-operator'

!----------------------------------------------------------------------
! Close the MCTDH operator file
!----------------------------------------------------------------------
    close(unit)

    return

  end subroutine wroper

!######################################################################

  subroutine wrlvcinfo

    use constants
    use channels
    use global
    use utils

    implicit none
    
    integer                         :: m,s,s1,s2,i
    real(d), parameter              :: thrsh=1e-3
    real(d), dimension(nmodes,nsta) :: maxpar
    real(d)                         :: fwp
    integer, dimension(nmodes)      :: indx

    write(ilog,'(/,50a)') ('*', i=1,50)
    write(ilog,'(11x,a)') 'LVC Hamiltonian Information'
    write(ilog,'(50a)') ('*', i=1,50)

    maxpar=0.0d0

!----------------------------------------------------------------------
! Frequency-weighted 1st-order interstate coupling terms (kappa)
!----------------------------------------------------------------------
    write(ilog,'(/,a)') '# Frequency-weighted 1st-order interstate'
    write(ilog,'(a,/)') '# coupling terms (kappa)'
    do m=1,nmodes
       do s=1,nsta
          fwp=kappa(m,s)/freq(m)
          if (abs(fwp).lt.thrsh) cycle
          write(ilog,'(a5,2(x,i2),x,a2,F9.6)') &
               'kappa',m,s,'= ',fwp
          if (abs(fwp).ge.maxpar(m,s)) maxpar(m,s)=abs(fwp)
       enddo
    enddo

!----------------------------------------------------------------------
! Frequency-weighted 1st-order interstate coupling terms (kappa)
!----------------------------------------------------------------------
    write(ilog,'(/,a)') '# Frequency-weighted 1st-order intrastate'
    write(ilog,'(a,/)') '# coupling terms (lambda)'
    do m=1,nmodes
       do s1=1,nsta-1
          do s2=s1+1,nsta
             fwp=lambda(m,s1,s2)/freq(m)
             if (abs(fwp).lt.thrsh) cycle
             write(ilog,'(a6,3(x,i2),x,a2,F9.6)') &
                  'lambda',m,s1,s2,'= ',fwp
             if (abs(fwp).ge.maxpar(m,s1)) maxpar(m,s1)=abs(fwp)
          enddo
       enddo
    enddo

!----------------------------------------------------------------------    
! Estimation of the relative spectroscopic importance of the normal
! modes
!----------------------------------------------------------------------
    write(ilog,'(/,a)') '# Estimation of the relative spectroscopic &
         importance'
    write(ilog,'(a)') '# of the normal modes'
    write(ilog,'(57a)') ('-', i=1,57)
    write(ilog,'(2x,3(a,5x))') 'State','Mode',&
         'Max. freq.-weighted parameter value'
    write(ilog,'(57a)') ('-', i=1,57)
    do s=1,nsta
       call dsortindxa1('D',nmodes,maxpar(:,s),indx)
       do m=1,nmodes
          write(ilog,'(i3,7x,i3,7x,F7.4)') s,indx(m),maxpar(indx(m),s)
       enddo
       write(ilog,*)
    enddo

    return

  end subroutine wrlvcinfo

!######################################################################

  subroutine wrdatfile

    use constants
    use iomod
    use global

    implicit none

    integer :: unit,m,s,s1,s2

!----------------------------------------------------------------------
! Open the lvc.dat file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file='lvc.dat',form='unformatted',status='unknown')

!----------------------------------------------------------------------
! Write the lvc.dat file
!----------------------------------------------------------------------
    ! Dimensions
    write(unit) nmodes
    write(unit) nsta

    ! Frequencies
    do m=1,nmodes
       write(unit) freq(m)
    enddo

    ! Energies
    do s=1,nsta
       write(unit) ener(s)
    enddo

    ! 1st-order intrastate coupling terms (kappa)
    do m=1,nmodes
       do s=1,nsta
          write(unit) kappa(m,s)
       enddo
    enddo
    
    ! 1st-order interstate coupling terms (lambda)
    do m=1,nmodes
       do s1=1,nsta-1
          do s2=s1+1,nsta
             write(unit) lambda(m,s1,s2)
          enddo
       enddo
    enddo

!----------------------------------------------------------------------
! Close the lvc.dat file
!----------------------------------------------------------------------
    close(unit)
    
    return

  end subroutine wrdatfile

!######################################################################

  subroutine finalise

    use channels
    use iomod

    implicit none

!----------------------------------------------------------------------
! Close the logfile
!----------------------------------------------------------------------
    close(ilog)

!----------------------------------------------------------------------
! Deallocation
!----------------------------------------------------------------------
    deallocate(ener)
    deallocate(grad)
    deallocate(nact)
    deallocate(mass)
    deallocate(xcoo0)
    deallocate(atnum)
    deallocate(atlbl)
    deallocate(nmlab)
    deallocate(freq)
    deallocate(nmcoo)
    deallocate(coonm)
    deallocate(kappa)
    deallocate(lambda)
    !if (allocated(lambdafile)) deallocate(lambdafile)
    
    return
    
  end subroutine finalise

!######################################################################

end program qc2vcham
