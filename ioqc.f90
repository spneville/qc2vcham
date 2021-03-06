module ioqc

  implicit none

  save

  integer :: idum
  logical :: ldum

contains

!######################################################################

  subroutine getdim

    use global
    
    implicit none

    if (qctyp.eq.4) then
       ! Columbus
       call getdim_columbus
    else if (qctyp.eq.5) then
       ! Turbomole, ricc2
       call getdim_ricc2
    else if (qctyp.eq.6) then
       ! Molcas, RASSCF
       call getdim_molcas_rasscf(qcfile(1))
    endif
    
    return
    
  end subroutine getdim

!######################################################################

  subroutine getdim_columbus

    use constants
    use channels
    use iomod
    use global

    implicit none

    integer            :: unit,n
    character(len=150) :: filename,string
    character(len=1)   :: adrt

!----------------------------------------------------------------------
! Determine the no. states from ciudgsm.drtIDRT.sp
!----------------------------------------------------------------------
    ! Open file
    call freeunit(unit)
    !filename=trim(qcfile(1))//'/LISTINGS/ciudgsm.drt1.sp'
    write(adrt,'(i1)') idrt
    filename=trim(qcfile(1))//'/LISTINGS/ciudgsm.drt'//adrt//'.sp'

    open(unit,file=filename,form='formatted',status='old')

    ! Read to the MRCI energy section
    n=0
5   read(unit,'(a)',end=111) string
    if (index(string,'final mr-sdci').ne.0) then
       n=n+1
       if (n.ne.2) goto 5
    else
       goto 5
    endif

    ! Determine the no. states
    nsta=0
10  read(unit,'(a)') string
    if (index(string,'mr-sdci').ne.0) then
       nsta=nsta+1
       goto 10
    endif

    ! Close file
    close(unit)

!----------------------------------------------------------------------
! Determine the no. atoms from the geom file
!----------------------------------------------------------------------
    ! Open file
    call freeunit(unit)
    filename=trim(qcfile(1))//'/geom'
    open(unit,file=filename,form='formatted',status='old')

    ! Determine the no. atoms
    natm=0
15  read(unit,'(a)',end=20) string
    if (index(string,'X').eq.0) natm=natm+1
    goto 15
20  continue
    
    ! No. Cartesian coordinates
    ncoo=3*natm

    ! No. normal modes
    ! N.B. for now we assume that the molecule is not linear...
    if (freqtyp.eq.4) then
       nmodes=ncoo
    else
       nmodes=ncoo-6
    endif
    
    ! Close file
    close(unit)

!----------------------------------------------------------------------
! Output the system dimensions to the log file
!----------------------------------------------------------------------
    write(ilog,'(/,2x,a,2x,i2)') "No. states:",nsta
    write(ilog,'(/,2x,a,2x,i2)') "No. atoms:",natm

    return

111 continue
    errmsg='It looks like the MRCI calculation did not complete...'
    call error_control

  end subroutine getdim_columbus

!######################################################################

  subroutine getdim_ricc2
    
    use constants
    use channels
    use iomod
    use global

    implicit none

    integer            :: unit,i
    character(len=150) :: string

!----------------------------------------------------------------------
! Open one of the ricc2 output files
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=qcfile(1),form='formatted',status='old')

!----------------------------------------------------------------------
! Determine the no. atoms, Cartesian coordinates and normal modes
!----------------------------------------------------------------------
5   read(unit,'(a)',end=888) string
    if (index(string,'atomic coordinates').eq.0) goto 5

    ! No. atoms
    natm=0
10  read(unit,'(a)') string
    if (string.ne.'') then
       natm=natm+1
       goto 10
    endif

    ! No. Cartesian coordinates
    ncoo=3*natm

    ! No. normal modes
    ! N.B. for now we assume that the molecule is not linear...
    if (freqtyp.eq.4) then
       nmodes=ncoo
    else
       nmodes=ncoo-6
    endif
       
!----------------------------------------------------------------------
! Determine the no. states (including the ground state)
!----------------------------------------------------------------------
15  read(unit,'(a)',end=999) string
    if (index(string,'||').eq.0) goto 15
    do i=1,3
       read(unit,*)
    enddo

    nsta=1
20  read(unit,'(a)') string
    if (index(string,'+===').eq.0) then
       nsta=nsta+1
       goto 20
    endif
    
!----------------------------------------------------------------------
! Close the ricc2 output file
!----------------------------------------------------------------------
    close(unit)

    return

888 continue
    errmsg='The geometry section could not be found in '//trim(qcfile(1))
    call error_control

999 continue
    errmsg='The excitation energy section could not be found in '&
         //trim(qcfile(1))
    call error_control
    

  end subroutine getdim_ricc2

!######################################################################

  subroutine getdim_molcas_rasscf(filename)

    use constants
    use channels
    use iomod
    use parsemod, only: lowercase
    use global

    implicit none

    integer            :: unit
    character(len=120) :: string
    character(len=*)   :: filename

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')
    
!----------------------------------------------------------------------
! Determine the number of states
!----------------------------------------------------------------------
    nsta=0
5   read(unit,'(a)',end=10) string
    call lowercase(string)
    if (index(string,'rlxroot').ne.0) nsta=nsta+1
    goto 5
    
10  continue

    if (nsta.eq.0) then
       errmsg='Error determining the no. states in '//trim(filename)
       call error_control
    endif

!----------------------------------------------------------------------
! Determine the no. vibrational degree of freedoms
!----------------------------------------------------------------------
    natm=0
    ncoo=0
    nmodes=0

    ! Determine the no. atoms
    rewind(unit)
15  read(unit,'(a)',end=999) string
    if (index(string,&
         'Cartesian Coordinates / Bohr, Angstrom').eq.0) goto 15
    read(unit,*)
    read(unit,*)
    read(unit,*)
20  read(unit,'(a)',end=999) string
    if (len(trim(string)).ne.0) then
       natm=natm+1
       goto 20
    endif

    ! No. Cartesian coordinates
    ncoo=3*natm

    ! No. normal modes
    ! N.B. for now we assume that the molecule is not linear...
    nmodes=ncoo-6
    
!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)

!----------------------------------------------------------------------
! Output the system dimensions to the log file
!----------------------------------------------------------------------
    write(ilog,'(/,2x,a,2x,i2)') "No. states:",nsta
    write(ilog,'(/,2x,a,2x,i2)') "No. atoms:",natm
    
    return

999 continue
    errmsg='Error parsing the Cartesian coordinates in '&
         //trim(filename)
    
  end subroutine getdim_molcas_rasscf
  
!######################################################################

  subroutine rdener

    use global

    implicit none

    integer                  :: n
    real(d), dimension(nsta) :: etmp
    character(len=150)       :: filename
    character(len=1)         :: adrt

!----------------------------------------------------------------------
! Read the energies of the electronic states in au
!----------------------------------------------------------------------
    if (qctyp.eq.4) then
       ! Columbus
       !filename=trim(qcfile(1))//'/LISTINGS/ciudgsm.drt1.sp'
       write(adrt,'(i1)') idrt
       filename=trim(qcfile(1))//'/LISTINGS/ciudgsm.drt'//adrt//'.sp'
       call rdener_columbus(etmp,filename)
    else if (qctyp.eq.5) then
       ! Turbomole, ricc2
       call rdener_ricc2(etmp,qcfile(1))
    else if (qctyp.eq.6) then
       ! Molcas, RASSCF
       call rdener_molcas_rasscf(etmp,qcfile(1))
    endif

!----------------------------------------------------------------------
! Convert to excitation energies in eV relative to the ground state
!----------------------------------------------------------------------
    ! Excitation energies in eV
    do n=2,nsta
       ener(n)=(etmp(n)-etmp(1))*eh2ev
    enddo
    ener(1)=0.0d0

    return
    
  end subroutine rdener

!######################################################################

  subroutine rdener_columbus(e,filename)

    use constants
    use iomod
    use global

    implicit none

    integer                  :: unit,n
    real(d), dimension(nsta) :: e
    character(len=150)       :: string
    character(len=*)         :: filename
    
!----------------------------------------------------------------------
! Read the Davidson corrected MRCI energies from ciudgsm.drtIDRT.sp
!----------------------------------------------------------------------
    ! Open file
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

    ! Read the Davdson-corrected MRCI energies
    n=0
5   read(unit,'(a)',end=999) string
    if (index(string,'eci+dv3').ne.0) then
       n=n+1
       read(string,'(12x,F20.12)') e(n)
       if (n.lt.nsta) goto 5
    else
       goto 5
    endif

    ! Close file
    close(unit)

    return

999 continue
    errmsg='Not all MRCI energies could be found... Quitting!'
    call error_control

  end subroutine rdener_columbus

!######################################################################

  subroutine rdener_ricc2(e,filename)

    use constants
    use iomod
    use global

    implicit none

    integer                  :: unit,n
    real(d), dimension(nsta) :: e
    character(len=150)       :: string
    character(len=*)         :: filename
    
!----------------------------------------------------------------------
! Open one of the ricc2 output files
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the ground state MP2 energy
!----------------------------------------------------------------------
5   read(unit,'(a)',end=888) string
    if (index(string,'Final MP2 energy').eq.0) goto 5
    
    read(string,'(50x,F18.10)') e(1)

!----------------------------------------------------------------------
! Read to the excitation energy section
!----------------------------------------------------------------------
10  read(unit,'(a)',end=999) string
    if (index(string,'||').eq.0) goto 10
    do n=1,3
       read(unit,*)
    enddo
    
!----------------------------------------------------------------------
! Read the excitation energies and compute the excited state energies
!----------------------------------------------------------------------
    do n=2,nsta
       read(unit,'(27x,F10.7)') e(n)
       e(n)=e(n)+e(1)
    enddo

!----------------------------------------------------------------------
! Close the ricc2 output file
!----------------------------------------------------------------------
    close(unit)
       
    return

888 continue
    errmsg='The MP2 energy could not be found in: '//trim(filename)
    call error_control

999 continue
    errmsg='The excited state energies could not be found in: '&
         //trim(filename)
    call error_control
    
  end subroutine rdener_ricc2

!######################################################################
  
  subroutine rdener_molcas_rasscf(e,filename)

    use constants
    use iomod
    use global

    implicit none

    integer                  :: unit,n
    real(d), dimension(nsta) :: e
    character(len=150)       :: string
    character(len=*)         :: filename

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the RASSCF energies
!----------------------------------------------------------------------
    n=0
5   read(unit,'(a)',end=10) string
    if (index(string,'RASSCF energy for state').ne.0) then
       n=n+1
       read(string,'(50x,F14.8)') e(n)
       if (n.eq.nsta) goto 10
    endif
    goto 5
    
10  continue

    if (n.ne.nsta) then
       errmsg='Not all state energies found in '//trim(filename)
       call error_control
    endif
    
!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)
    
    return    
    
  end subroutine rdener_molcas_rasscf
    
!######################################################################

  subroutine rdgrad

    use global
    
    if (qctyp.eq.4) then
       ! Columbus
       call rdgrad_columbus
    else if (qctyp.eq.5) then
       ! Turbomole, ricc2
       call rdgrad_ricc2
    else if (qctyp.eq.6) then
       ! Molcas, RASSCF
       call rdgrad_molcas_rasscf(qcfile(1))
    endif

    return

  end subroutine rdgrad

!######################################################################

  subroutine rdgrad_columbus

    use constants
    use global
    use iomod

    implicit none

    integer            :: i,j,k,unit
    character(len=150) :: filename
    character(len=2)   :: asta
    character(len=1)   :: adrt

!----------------------------------------------------------------------
! Read the energy gradients in terms of the Cartesian coordinates
!----------------------------------------------------------------------
    call freeunit(unit)

    ! DRT no.
    write(adrt,'(i1)') idrt
    
    ! Loop over states
    do i=1,nsta

       ! Open the gradient file
       write(asta,'(i2)') i
       !filename=trim(qcfile(1))//'/GRADIENTS/cartgrd.drt1.state'&
       !     //trim(adjustl(asta))//'.sp'
       filename=trim(qcfile(1))//'/GRADIENTS/cartgrd.drt'//adrt//&
            '.state'//trim(adjustl(asta))//'.sp'
       open(unit,file=filename,form='formatted',status='old')

       ! Read the gradient file
       do j=1,natm
          read(unit,*) (grad(k,i), k=j*3-2,j*3)
       enddo

       ! Close the gradient file
       close(unit)

    enddo

    return

  end subroutine rdgrad_columbus

!######################################################################

  subroutine rdgrad_ricc2

    use constants
    use global
    use iomod

    implicit none

    integer               :: i,j,k,n,f,nfiles,unit,ista,nblock,indx,&
                             ires
    real(d), dimension(5) :: ftmp
    character(len=120)    :: string
    character(len=15)     :: fmat
    
!----------------------------------------------------------------------
! The Turbomole ricc2 code can only compute one excited state
! gradient per calculation. Therefore, we have to read multiple output
! files - one per excited state
!----------------------------------------------------------------------
    ! Determine the no. ricc2 output files
    nfiles=0
    do i=1,size(qcfile)
       if (qcfile(i).ne.'') nfiles=nfiles+1
    enddo
       
    ! Loop over ricc2 output files, reading the gradient vector for
    ! each
    call freeunit(unit)
    do f=1,nfiles
       
       ! Open the current ricc2 output file
       open(unit,file=qcfile(f),form='formatted',status='old')
       
       ! Determine the state number for the current file
5      read(unit,'(a)',end=999) string
       if (index(string,'number, symmetry, multiplicity').eq.0) goto 5
       read(string,'(41x,i2)') ista
       ista=ista+1
       
       ! Read the gradient vector
       do i=1,14
          read(unit,*)
       enddo
       
       nblock=ceiling(real(natm)/5)

       ! First nblock-1 blocks
       do i=1,nblock-1
          read(unit,*)
          read(unit,*)
          do j=1,3
             read(unit,'(7x,5D14.11)') (ftmp(k), k=1,5)
             do k=1,5
                ! Atom no.
                n=(i-1)*5+k
                ! grad index
                indx=n*3-3+j
                ! Fill in the indx'th grad element
                grad(indx,ista)=ftmp(k)
             enddo
          enddo
       enddo
       
       ! Last block
       read(unit,*)
       read(unit,*)
       ires=natm-(nblock-1)*5
       fmat=''
       write(fmat,'(a4,i1,a7)') '(7x,',ires,'D14.11)'
       do j=1,3
          read(unit,fmat) (ftmp(k), k=1,ires)
          do k=1,ires
             ! Atom no.
             n=(nblock-1)*5+k
             ! xgrad index
             indx=n*3-3+j
             ! Fill in the indx'th grad element
             grad(indx,ista)=ftmp(k)
          enddo
       enddo
       
       ! Close the current ricc2 output file
       close(unit)
       
    enddo

   return

999 continue
    errmsg='The gradient section could not be found in '&
         //trim(qcfile(i))
    call error_control
    
  end subroutine rdgrad_ricc2

!######################################################################

  subroutine rdgrad_molcas_rasscf(filename)

    use constants
    use global
    use iomod
    
    implicit none

    integer            :: unit,n,i,j
    character(len=*)   :: filename
    character(len=120) :: string
    character(len=5)   :: atmp
    
!----------------------------------------------------------------------
! Open the Molcas output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------    
! Read in the gradients
!----------------------------------------------------------------------
    n=0
    
5   read(unit,'(a)',end=999) string

    if (index(string,'Molecular gradients').ne.0) then

       n=n+1

       do i=1,7
          read(unit,*)
       enddo

       do i=1,natm
          read(unit,*) atmp,(grad(j,n),j=i*3-2,i*3)
       enddo
       
       if (n.eq.nsta) goto 10

    endif
       
    goto 5

10  continue

!----------------------------------------------------------------------
! Close the Molcas output file
!----------------------------------------------------------------------
    close(unit)
    
    return

999 continue
    errmsg='Error parsing the gradients in '//trim(filename)
    call error_control
        
  end subroutine rdgrad_molcas_rasscf
    
!######################################################################

  subroutine rdnact

    use global

    implicit none

    if (qctyp.eq.4) then
       ! Columbus
       call rdnact_columbus
    else if (qctyp.eq.6) then
       ! Molcas, RASSCF
       call rdnact_molcas_rassscf(qcfile(1))
    endif

    return

  end subroutine rdnact

!######################################################################

  subroutine rdnact_columbus

    use constants
    use global
    use iomod

    implicit none

    integer            :: s1,s2,i,j,unit
    character(len=150) :: filename
    character(len=2)   :: asta1,asta2
    character(len=1)   :: adrt

!----------------------------------------------------------------------
! Read the NACTs (multiplied by the energy difference!) in terms of 
! the Cartesian coordinates
!----------------------------------------------------------------------
    call freeunit(unit)

    ! DRT no.
    write(adrt,'(i1)') idrt
    
    ! Loop unique pairs of states
    do s1=1,nsta-1
       do s2=s1+1,nsta

          ! Open the NACT file
          write(asta1,'(i2)') s1
          write(asta2,'(i2)') s2
          !filename=trim(qcfile(1))//'/GRADIENTS/cartgrd.nad.drt1.state'&
          !  //trim(adjustl(asta1))//'.drt1.state'&
          !  //trim(adjustl(asta2))//'.sp'
          filename=trim(qcfile(1))//'/GRADIENTS/cartgrd.nad.drt'//adrt//&
               '.state'//trim(adjustl(asta1))//'.drt'//adrt//'.state'&
               //trim(adjustl(asta2))//'.sp'
          open(unit,file=filename,form='formatted',status='old')

          ! Read the NACT file
          do i=1,natm
             read(unit,*) (nact(j,s1,s2), j=i*3-2,i*3)
          enddo

          ! Fill in the lower triangle
          nact(:,s2,s1)=-nact(:,s1,s2)

          ! Close the NACT file
          close(unit)

       enddo
    enddo

    return

  end subroutine rdnact_columbus

!######################################################################

  subroutine rdnact_molcas_rassscf(filename)

    use constants
    use global
    use iomod
    
    implicit none

    integer                       :: unit,i,j,n,s1,s2
    integer, dimension(2,nsta**2) :: ipair
    real*8, dimension(ncoo)       :: nact_ci,nact_csf
    character(len=*)              :: filename
    character(len=120)            :: string
    character(len=5)              :: atmp
    
!----------------------------------------------------------------------
! Open the Molcas output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Determine the ordering of the NACT calculations
!----------------------------------------------------------------------
    ipair=0

    n=0
    
5   read(unit,'(a)',end=10) string
    if (index(string,&
         'Lagrangian multipliers are calculated for states').ne.0) then
       n=n+1
       read(string,'(59x,i2,2x,i2)') ipair(1,n),ipair(2,n)
    endif

    goto 5

10  continue

!----------------------------------------------------------------------
! Read the in NACTs (multiplied by the energy differences)
!----------------------------------------------------------------------
    rewind(unit)

    n=0

15  read(unit,'(a)',end=20) string

    if (index(string,'CI derivative coupling').ne.0) then

       n=n+1

       s1=ipair(1,n)
       s2=ipair(2,n)

       ! CI contribution
       do i=1,7
          read(unit,*)
       enddo
       do i=1,natm
          read(unit,*) atmp,(nact_ci(j),j=i*3-2,i*3)
       enddo

       ! CSF contribution
       do i=1,13
          read(unit,*)
       enddo
       do i=1,natm
          read(unit,*) atmp,(nact_csf(j),j=i*3-2,i*3)
       enddo
       
       ! Total NACT
       nact(:,s1,s2)=nact_ci+nact_csf
       nact(:,s2,s1)=-nact(:,s1,s2)
       
    endif
    
    goto 15
    
20  continue
    
!----------------------------------------------------------------------
! Close the Molcas output file
!----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine rdnact_molcas_rassscf
    
!######################################################################

  subroutine rddip
    
    use global

    implicit none

    if (qctyp.eq.4) then
       ! Columbus
       call rddip_columbus
    endif

    return

  end subroutine rddip

!######################################################################

  subroutine rddip_columbus

    use constants
    use global
    use iomod

    implicit none

    integer            :: s,s1,s2,i,j,unit
    character(len=150) :: filename,string
    character(len=2)   :: asta1,asta2
    character(len=1)   :: adrt

!----------------------------------------------------------------------
! Read the on-diagonal elements of the dipole matrix
!----------------------------------------------------------------------
    call freeunit(unit)

    ! DRT no.
    write(adrt,'(i1)') idrt
    
    ! Loop over states
    do s=1,nsta
       
       ! Open the propls file
       write(asta1,'(i2)') s
       !filename=trim(qcfile(1))//'/LISTINGS/propls.ci.drt1.state'&
       !     //trim(adjustl(asta1))//'.sp'
       filename=trim(qcfile(1))//'/LISTINGS/propls.ci.drt'//adrt//&
            '.state'//trim(adjustl(asta1))//'.sp'
       open(unit,file=filename,form='formatted',status='old')
       
       ! Read the dipole moment
5      read(unit,'(a)',end=999) string
       if (index(string,'Dipole moments:').eq.0) goto 5
       do i=1,4
          read(unit,*)
       enddo
       read(unit,'(11x,3(2x,F14.8))') (dipole(i,s,s),i=1,3)

       ! Close the propls file
       close(unit)

    enddo

!----------------------------------------------------------------------
! Read the off-diagonal elements of the dipole matrix
!----------------------------------------------------------------------
    ! Loop unique pairs of states
    do s1=1,nsta-1
       do s2=s1+1,nsta

          ! DRT no.
          write(adrt,'(i1)') idrt
          
          ! Open the trncils file
          write(asta1,'(i2)') s1
          write(asta2,'(i2)') s2
          !filename=trim(qcfile(1))//'/LISTINGS/trncils.drt1.state'&
          !  //trim(adjustl(asta1))//'.drt1.state'&
          !  //trim(adjustl(asta2))
          filename=trim(qcfile(1))//'/LISTINGS/trncils.drt'//adrt//&
               '.state'//trim(adjustl(asta1))//'.drt'//adrt//'.state'&
               //trim(adjustl(asta2))
          open(unit,file=filename,form='formatted',status='old')

          ! Read the transition diole moment
10        read(unit,'(a)',end=999) string
          if (index(string,'Transition moment components:').eq.0) goto 10
          do i=1,3
             read(unit,*)
          enddo
          read(unit,'(13x,3(F13.6))') (dipole(i,s1,s2),i=1,3)
          dipole(:,s2,s1)=dipole(:,s1,s2)

          ! Close the trncils file
          close(unit)

       enddo
    enddo

    return

999 continue
    errmsg='No dipole moment matrix element could be found in: '&
         //trim(filename)
    call error_control

  end subroutine rddip_columbus

!######################################################################

  subroutine approx_lambda

    use constants
    use global
    use iomod

    implicit none

    integer                              :: i,j,nfiles,n,m
    integer, dimension(nmodes,2)         :: imap
    real(d), dimension(:,:), allocatable :: xcoo,qcoo,e
    real(d), dimension(nsta)             :: e0
    real(d), dimension(nmodes)           :: dq
    real(d)                              :: func,fplus,fminus,f0
    real(d), parameter                   :: thrsh1=1e-3,thrsh2=1e-5
    
!-----------------------------------------------------------------------
! Allocate and initialise arrays
!-----------------------------------------------------------------------
    !nfiles=size(lambdafiles)
    nfiles=nlambdafiles
    
    allocate(xcoo(ncoo,nfiles))
    xcoo=0.0d0

    allocate(qcoo(ncoo,nfiles))
    qcoo=0.0d0

    allocate(e(nsta,nfiles))
    e=0.0d0
    
!-----------------------------------------------------------------------
! Read the Cartesian coordinates from each file
!-----------------------------------------------------------------------
    do i=1,nfiles
       call getxcoo_1file(xcoo(:,i),lambdafile(i),qctyp)
    enddo

    ! Convert to displacements in angstrom relative to x0
    do i=1,nfiles
       xcoo(:,i)=(xcoo(:,i)-xcoo0)/ang2bohr
    enddo
    
!-----------------------------------------------------------------------
! Compute the normal mode coordinates for each file
!-----------------------------------------------------------------------
    do i=1,nfiles
       qcoo(:,i)=matmul(coonm,xcoo(:,i))
    enddo

!-----------------------------------------------------------------------
! Determine the step sizes for each mode
!-----------------------------------------------------------------------
    dq=0.0d0

    do i=1,nfiles

       ! Check: each geometry must correspond to displacement
       ! along one, and only one normal mode
       n=0
       do j=1,nmodes
          if (abs(qcoo(j,i)).gt.thrsh1) n=n+1          
       enddo
       if (n.gt.1) then
          errmsg='Error in approx_lambda: more than one normal mode &
               is displaced in the file: '//trim(lambdafile(i))
          call error_control
       endif

       ! Determine the step size for th normal mode displaced
       ! along in the current file
       do j=1,nmodes
          if (abs(qcoo(j,i)).gt.thrsh1) then
             if (dq(j).eq.0.0d0) then
                dq(j)=abs(qcoo(j,i))
             else
                if (abs(dq(j))-abs(qcoo(j,i)).gt.thrsh2) then
                   errmsg=''
                   write(errmsg,'(a,i2)') 'Error in approx_lambda: &
                        unequal displacments for mode ',j
                   call error_control
                endif
             endif
          endif
       enddo
       
    enddo

!-----------------------------------------------------------------------
! Determine the mapping between the normal mode displacements and
! the file numbers:
!
! imap(m,1) <-> index of the file corresponding to the positive
!               displacement along mode m
! imap(m,2) <-> index of the file corresponding to the negative
!               displacement along mode m
!-----------------------------------------------------------------------
    imap=0
    do i=1,nfiles
       do j=1,nmodes
          if (abs(qcoo(j,i)).gt.thrsh1) then
             if (qcoo(j,i).gt.0.0d0) then
                imap(j,1)=i
             else
                imap(j,2)=i
             endif
          endif
       enddo
    enddo

!-----------------------------------------------------------------------
! Read the energies for each file
!-----------------------------------------------------------------------
    do i=1,nfiles
       call rdener_1file(e(:,i),lambdafile(i),qctyp)
    enddo

!-----------------------------------------------------------------------
! Read the energies at the reference geometry
!-----------------------------------------------------------------------
    call rdener_1file(e0,qcfile(1),qctyp)

!-----------------------------------------------------------------------
! Compute the approximate lambda values:
!
! lambda_m^(i,j) ~ sqrt( 1/8 d^2 (V_i - V_j)**2/d Q_m^2
!                       - 1/4 (kappa_m^(i)**2 + kappa_m^(j)**2)
!                       + 1/2 kappa_m^(i) kappa_m^(j))
!-----------------------------------------------------------------------
    ! Loop over the normal modes
    do m=1,nmodes

       ! Cycle if we don't have all the output required for the
       ! current mode
       if (imap(m,1).eq.0.or.imap(m,2).eq.0) cycle

       ! Calculate the approximation to lambda_m^(i,j) for
       ! all pairs of states
       do i=1,nsta-1
          do j=i+1,nsta

             fplus=(e(i,imap(m,1))-e(j,imap(m,1)))**2
             fminus=(e(i,imap(m,2))-e(j,imap(m,2)))**2
             f0=(e0(i)-e0(j))**2

             func=(1.0d0/8.0d0)*(fplus+fminus-2.0d0*f0)/(dq(m)**2)
             
             func=func-0.25d0*(kappa(m,i)**2+kappa(m,j)**2)&
                  +0.5d0*kappa(m,i)*kappa(m,j)

             ! DOES THIS MAKE SENSE?
             if (func.gt.0.0d0) then
                func=sqrt(abs(func))
                
                lambda(m,i,j)=func*eh2ev
                lambda(m,j,i)=lambda(m,i,j)
             endif
             
          enddo
       enddo

    enddo
    
!-----------------------------------------------------------------------
! Deallocate arrays
!-----------------------------------------------------------------------
    deallocate(xcoo)
    deallocate(qcoo)
    deallocate(e)
    
    return
    
  end subroutine approx_lambda

!######################################################################

  subroutine getxcoo_1file(xcoo,filename,ityp)

    use constants
    use iomod
    use global
    
    implicit none
    
    integer                  :: ityp,unit
    real(d), dimension(ncoo) :: xcoo
    character(len=*)         :: filename

    if (ityp.eq.1) then
       ! G98
       call getxcoo_g98(xcoo,filename)
    else if (ityp.eq.2) then
       ! CFOUR
       call getxcoo_cfour(xcoo,filename)
    else if (ityp.eq.4) then
       ! Columbus: not yet implemented
       errmsg='The getxcoo_columbus subroutine still needs to be &
            written...'
       call error_control
    else if (ityp.eq.5) then
       ! Turbomole, ricc2
       call getxcoo_ricc2(xcoo,filename)
    endif
       
    return
    
  end subroutine getxcoo_1file
    
!######################################################################

  subroutine rdener_1file(e,filename,ityp)

    use constants
    use iomod
    use global
    
    implicit none
    
    integer                  :: ityp,unit
    real(d), dimension(nsta) :: e
    character(len=*)         :: filename
    character(len=250)       :: aciudgsm
    character(len=1)         :: adrt
    
    if (ityp.eq.4) then
       ! Columbus
       write(adrt,'(i1)') idrt
       aciudgsm=trim(filename)//'/LISTINGS/ciudgsm.drt'//adrt//'.sp'
       call rdener_columbus(e,aciudgsm)
    else if (ityp.eq.5) then
       ! Turbomole, ricc2
       call rdener_ricc2(e,filename)
    endif

    return

  end subroutine rdener_1file

!######################################################################
       
  subroutine rdfreqfile

    use constants
    use global
    use iomod

    implicit none

!----------------------------------------------------------------------
! Read the reference Cartesian coordinates
!----------------------------------------------------------------------
    call getxcoo0

!----------------------------------------------------------------------
! Deuteration: we can only do this if we are reading in the Hessian
! to mass-weight and diagonalise, not if we are reading the normal
! modes directly from file
!----------------------------------------------------------------------
    if (ldeuterate) then
       if (freqtyp.eq.1) then
          ! G98: Exit as normal modes read directly from file
          errmsg='Deuteration is not compatible with G98 frequency &
               calculations'
          call error_control
       else if (freqtyp.eq.4) then
          ! Projection2: Exit as the projected normal modes are
          ! directly read from file
          errmsg='Deuteration is not compatible with Projection2 &
               calculations'
          call error_control
       else
          call deuterate
       endif
    endif
    
!----------------------------------------------------------------------
! Read the normal modes, frequencies and symmetry labels
!----------------------------------------------------------------------
    call getmodes

    return
    
  end subroutine rdfreqfile

!######################################################################
! freqtype: determines the program used for the frequency calculation,
!           and sets freqtyp accordingly:
!          
!           freqtyp = 1 <-> G98
!                     2 <-> CFOUR
!                     3 <-> Hessian file
!                     4 <-> Projection2 data file
!                     5 <-> Turbomole, aoforce  
!######################################################################
  subroutine freqtype

    use constants
    use global
    use iomod

    implicit none
    
    integer            :: unit
    character(len=120) :: string
    logical            :: dir

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    freqtyp=-1

!----------------------------------------------------------------------
! Determine the quantum chemistry program used for the frequency
! calculation
!----------------------------------------------------------------------
    if (isg98(freqfile)) then
       ! G98
       freqtyp=1
    else if (iscfour(freqfile)) then
       ! CFOUR
       freqtyp=2
    else if (ishessian(freqfile)) then
       ! Hessian
       freqtyp=3
    else if (isprojection2(freqfile)) then
       ! Projection2 data file
       freqtyp=4
    else if (isaoforce(freqfile)) then
       ! Turbomole, aoforce
       freqtyp=5
    endif

!----------------------------------------------------------------------
! Check that the quantum chemistry program used is supported
!----------------------------------------------------------------------
    if (freqtyp.eq.-1) then
       errmsg='The quantum chemistry program used for the &
            frequency calculation is not supported.'
       call error_control
    endif

    return

  end subroutine freqtype

!######################################################################
! qctype: determines the quantum chemistry program used for the
!         coupling coefficient calculations
!
!         qctyp = 4 <-> Columbus
!                 5 <-> Turbomole, ricc2
!                 6 <-> Molcas, RASSCF
!######################################################################
  subroutine qctype

    use constants
    use global
    use iomod

    implicit none

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    qctyp=-1

!----------------------------------------------------------------------
! Determine the quantum chemistry program used for the coupling
! coefficient calculation
!----------------------------------------------------------------------
    if (iscolumbus(qcfile(1))) then
       ! Columbus
       qctyp=4
    else if (isricc2(qcfile(1))) then
       ! Turbomole, ricc2
       qctyp=5
    else if (ismolcasrasscf(qcfile(1))) then
       ! Molcas, RASSCF
       qctyp=6
    endif

!----------------------------------------------------------------------
! Check that the quantum chemistry program used is supported
!----------------------------------------------------------------------
    if (qctyp.eq.-1) then
       errmsg='The quantum chemistry program used for the &
            coupling coefficient calculation is not supported.'
       call error_control
    endif

!----------------------------------------------------------------------
! Set the logical flags controling what is to be read from the
! quantum chemistry output
!----------------------------------------------------------------------
    if (qctyp.eq.4) then
       ! Columbus: gradients and NACTs
       lgrad=.true.
       lnact=.true.
    else if (qctyp.eq.5) then
       ! Turbomole, ricc2: gradients only
       lgrad=.true.
    else if (qctyp.eq.6) then
       ! Molcas, RASSCF: gradients and NACTs
       lgrad=.true.
       lnact=.true.
    endif

    return

  end subroutine qctype

!######################################################################

  function iscolumbus(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether the 'file' is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (.not.dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Check to see if the LISTINGS subdirectory exists
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/LISTINGS/.',exist=found)

    return

  end function iscolumbus

!######################################################################

  function isricc2(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether the 'file' is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Check whether the calculation was performed using the Turbomole
! ricc2 code
!----------------------------------------------------------------------
10  read(unit,'(a)',end=999) string
    if (index(string,' R I C C 2 - PROGRAM').ne.0) then
       found=.true.
    else
       goto 10
    endif

!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)

    return

999 continue
    found=.false.
    return

  end function isricc2

!######################################################################

  function ismolcasrasscf(filename) result(found)

    use constants
    use iomod
    
    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir
    
!----------------------------------------------------------------------
! First determine whether the 'file' is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Check whether this is a Molcas RASSCF calculation
!----------------------------------------------------------------------
10  read(unit,'(a)',end=999) string
    if (index(string,&
         '*              Molecular gradients               *').ne.0) then
       found=.true.
    else
       goto 10
    endif

!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)
    
    return

999 continue
    found=.false.
    return
    
  end function ismolcasrasscf
    
!######################################################################

  function isg98(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether freqfile is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Check whether the calculation was performed using G98
!----------------------------------------------------------------------
    read(unit,'(a)') string
    if (index(string,'Entering Gaussian System').ne.0) then
       found=.true.
    else
       found=.false.
    endif

!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

  end function isg98

!######################################################################

  function iscfour(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether freqfile is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (.not.dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Check to see if the cfour FCMFINAL file exists
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/FCMFINAL',exist=found)

    return

  end function iscfour

!######################################################################
  
  function ishessian(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether freqfile is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Check whether the file is a Hessian file
!----------------------------------------------------------------------
    read(unit,'(a)') string
    if (index(string,'Hessian').ne.0) then
       found=.true.
    else
       found=.false.
    endif

!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

  end function ishessian

!######################################################################

  function isprojection2(filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit,ierr
    character(len=*)   :: filename
    character(len=120) :: header
    logical            :: found

!-----------------------------------------------------------------------
! Open file
!-----------------------------------------------------------------------
    open(unit,file=filename,form='unformatted',status='old')

!-----------------------------------------------------------------------
! Attempt to read the file header
!-----------------------------------------------------------------------
    read(unit,iostat=ierr) header

!-----------------------------------------------------------------------
! If the read was unsuccessful, then we know that the file is not
! a projection2 data file
!-----------------------------------------------------------------------
    if (ierr.ne.0) then
       found=.false.
       return
    endif

!-----------------------------------------------------------------------
! If the read was successful, then check that the file header is
! consistent with a projection2 file header
!-----------------------------------------------------------------------
    if (index(header,'Projection2').ne.0) then
       found=.true.
    else
       found=.false.
    endif

!-----------------------------------------------------------------------
! Close file
!-----------------------------------------------------------------------
    close(unit)
    
    return
    
  end function isprojection2

!######################################################################

  function isaoforce (filename) result(found)

    use constants
    use iomod

    implicit none

    integer            :: unit
    character(len=*)   :: filename
    character(len=120) :: string
    logical            :: found,dir

!----------------------------------------------------------------------
! First determine whether freqfile is actually a file.
! This is necessary as for certain programs, the name of a directory
! will actually be passed instead
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/.',exist=dir)

    if (dir) then
       found=.false.
       return
    endif

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Check whether the calculation was performed using the aoforce
! module in Turbomole
!----------------------------------------------------------------------
    found=.false.

5   read(unit,'(a)',end=10) string
    if (index(string,'a o f o r c e - program').ne.0) then
       found=.true.
    else
       goto 5
    endif

10  continue
    
!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)
    
    return
    
  end function isaoforce
    
!######################################################################

  subroutine getxcoo0

    use constants
    use global
    use iomod

    implicit none

    real(d), dimension(ncoo) :: xcoo

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    ldum=.false.
    idum=0

!----------------------------------------------------------------------
! Read in the reference Cartesian coordinates
!----------------------------------------------------------------------
    if (freqtyp.eq.1) then
       ! G98
       call getxcoo_g98(xcoo,freqfile)
    else if (freqtyp.eq.2) then
       ! CFOUR
       call getxcoo_cfour(xcoo,freqfile)
    else if (freqtyp.eq.3) then
       ! Hessian
       call getxcoo_hessian(xcoo,freqfile)
    else if (freqtyp.eq.4) then
       ! Projection2 data file
       call getxcoo_projection2(xcoo,freqfile)
    else if (freqtyp.eq.5) then
       ! Turbomole, aoforce
       call getxcoo_aoforce(xcoo,freqfile)
    endif

!----------------------------------------------------------------------
! Fill in the xcoo0 array
!----------------------------------------------------------------------
    xcoo0=xcoo

    return

  end subroutine getxcoo0

!######################################################################
  
  subroutine getxcoo_g98(xcoo,filename)

    use constants
    use global
    use iomod

    implicit none
  
    integer                  :: unit,i,j
    real(d), dimension(ncoo) :: xcoo
    character(len=*)         :: filename
    character(len=120)       :: string

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the Cartesian coordinates
!----------------------------------------------------------------------
5   read(unit,'(a)',end=999) string
    if (index(string,'Z-Matrix orientation').eq.0) goto 5

    do i=1,4
       read(unit,*)
    enddo

    do i=1,natm
       read(unit,'(14x,i2,18x,3F12.6)') atnum(i),(xcoo(j), j=i*3-2,i*3)
       atlbl(i)=num2lbl(atnum(i))
       mass(i*3-2:i*3)=num2mass(atnum(i))
    enddo

    ! Convert to Bohr
    xcoo=xcoo*ang2bohr

!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

999 continue
    errmsg='The Cartesian coordinates could not be found in: '&
         //trim(filename)
    call error_control

  end subroutine getxcoo_g98

!######################################################################

  subroutine getxcoo_cfour(xcoo,filename)

    use constants
    use iomod
    use global

    implicit none

    integer                  :: unit,i,n
    real(d), dimension(ncoo) :: xcoo
    logical                  :: found
    character(len=*)         :: filename
    character(len=120)       :: string
    character(len=2)         :: atmp

!----------------------------------------------------------------------
! First check to make sure that the cfour.log file exists
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/cfour.log',exist=found)

    if (.not.found) then
       errmsg='The CFOUR log file is assumed to be named cfour.log. &
            This file could not be found in: '//trim(filename)
       call error_control
    endif

!----------------------------------------------------------------------
! Open the CFOUR log file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=trim(filename)//'/cfour.log',form='formatted',&
         status='old')

!----------------------------------------------------------------------
! Read the reference Cartesian coordinates from the CFOUR log file
!----------------------------------------------------------------------
5   read(unit,'(a)',end=999) string
    if (index(string,'Coordinates (in bohr)').eq.0) goto 5

    do i=1,2
       read(unit,*)
    enddo

    n=0
10  read(unit,'(a)') string
    if (index(string,'---').eq.0) then
       if (string(6:6).ne.'X') then
          n=n+1
          read(string,'(5x,a2,8x,i2,3x,3(F15.8))') &
               atlbl(n),atnum(n),(xcoo(i), i=n*3-2,n*3)
          mass(n*3-2:n*3)=num2mass(atnum(n))
       else
          ldum=.true.
          idum=n+1
       endif
       goto 10
    endif

!----------------------------------------------------------------------
! Close the CFOUR log file
!----------------------------------------------------------------------
    close(unit)

    return

999 continue
    errmsg='The Cartesian coordinates could not be found in: '&
         //trim(filename)//'/cfour.log'
    call error_control

  end subroutine getxcoo_cfour

!######################################################################

  subroutine getxcoo_hessian(xcoo,filename)

    use constants
    use iomod
    use global

    implicit none

    integer                  :: unit,i,j
    real(d), dimension(ncoo) :: xcoo
    character(len=*)         :: filename

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the Cartesian coordinates
!----------------------------------------------------------------------
    read(unit,*)
    do i=1,natm
       read(unit,*) atlbl(i),(xcoo(j), j=i*3-2,i*3)
       mass(i*3-2:i*3)=lbl2mass(atlbl(i))
       atnum(i)=lbl2num(atlbl(i))
    enddo

    ! Convert to Bohr
    xcoo=xcoo*ang2bohr
    
!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

  end subroutine getxcoo_hessian

!######################################################################

  subroutine getxcoo_projection2(xcoo,filename)

    use constants
    use iomod
    use global
    
    implicit none

    integer                  :: unit,idum,i
    real(d), dimension(ncoo) :: xcoo
    character(len=*)         :: filename
    character(len=120)       :: header

!-----------------------------------------------------------------------
! Open file
!-----------------------------------------------------------------------
    open(unit,file=filename,form='unformatted',status='old')

!-----------------------------------------------------------------------
! Read the Cartesian coordinates: access is sequential, so we first
! have to read past the header an no. Cartesian coordinates
!-----------------------------------------------------------------------
    ! Header
    read(unit) header

    ! No. coordinates
    read(unit) idum

    ! Cartesian coordinates (in Angstrom)
    read(unit) xcoo

    ! Convert to Bohr
    xcoo=xcoo*ang2bohr

!-----------------------------------------------------------------------
! Read in the masses and atom labels
!-----------------------------------------------------------------------
    ! Masses
    read(unit) mass
    
    ! Atom labels
    read(unit) atlbl

    ! Determine the atomic numbers from the atom labels
    do i=1,natm
       atnum(i)=lbl2num(atlbl(i))
    enddo
    
!-----------------------------------------------------------------------
! Close file
!-----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine getxcoo_projection2

!######################################################################

  subroutine getxcoo_aoforce(xcoo,filename)

    use constants
    use global
    use iomod

    implicit none
  
    integer                 :: unit,i,j
    real*8, dimension(ncoo) :: xcoo
    real*8                  :: ftmp
    character(len=*)        :: filename
    character(len=120)      :: string

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the Cartesian coordinates
!----------------------------------------------------------------------
    ! Read to the coordinates section
5   read(unit,'(a)',end=999) string
    if (index(string,'atomic coordinates').eq.0) goto 5

    ! Read the coordinates (in Bohr)
    do i=1,natm
       read(unit,'(x,3(2x,F12.8),4x,a2,9x,F6.4)') &
            (xcoo(j), j=i*3-2,i*3),atlbl(i),ftmp
       atnum(i)=int(ftmp)
       mass(i*3-2:i*3)=num2mass(atnum(i))
       call uppercase(atlbl(i)(1:1))
    enddo

!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

999 continue
    errmsg='The Cartesian coordinates could not be found in: '&
         //trim(filename)
    call error_control

  end subroutine getxcoo_aoforce
  
!######################################################################

  subroutine getxcoo_ricc2(xcoo,filename)

    use constants
    use iomod
    use global
    
    implicit none

    integer                  :: unit,i,j
    real(d), dimension(ncoo) :: xcoo
    character(len=*)         :: filename
    character(len=150)       :: string

!----------------------------------------------------------------------
! Open file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=trim(filename),form='formatted',status='old')

!----------------------------------------------------------------------
! Read the Cartesian coordinates
!----------------------------------------------------------------------
5   read(unit,'(a)',end=999) string
    if (index(string,'atomic coordinates').eq.0) goto 5

    do i=1,natm
       read(unit,'(1x,3(F14.8),15x,i2)') (xcoo(j), j=i*3-2,i*3),atnum(i)
       atlbl(i)=num2lbl(atnum(i))
       mass(i*3-2:i*3)=num2mass(atnum(i))
    enddo

!----------------------------------------------------------------------
! Close file
!----------------------------------------------------------------------
    close(unit)

    return

999 continue
    errmsg='The geometry section could not be found in '//trim(qcfile(1))
    call error_control
    
  end subroutine getxcoo_ricc2
    
!######################################################################

  function num2lbl(num) result(lbl)

    use constants
    use iomod

    implicit none

    integer          :: num
    character(len=2) :: lbl

    if (num.eq.1) then
       lbl='H'
    else if (num.eq.6) then
       lbl='C'
    else if (num.eq.7) then
       lbl='N'
    else if (num.eq.8) then
       lbl='O'
    else
       write(errmsg,'(a,x,i2,x,a)') 'The atomic number',num,&
            'is not supported. See function num2lbl.'
       call error_control
    endif

    return

  end function num2lbl

!######################################################################

  function num2mass(num) result(mass)

    use constants
    use iomod

    implicit none

    integer :: num
    real(d) :: mass

    if (num.eq.1) then
       mass=1.00794d0
    else if (num.eq.6) then
       mass=12.0107d0
    else if (num.eq.7) then
       mass=14.0067d0
    else if (num.eq.8) then
       mass=15.9994d0
    else
       write(errmsg,'(a,x,i2,x,a)') 'The atomic number',num,&
            'is not supported. See function num2mass.'
       call error_control
    endif

    return

  end function num2mass
  
!######################################################################
  
  function lbl2mass(lbl) result(mass)

    use constants
    use iomod

    implicit none

    real(d)          :: mass
    character(len=*) :: lbl

    if (lbl.eq.'H') then
       mass=1.00794d0
    else if (lbl.eq.'C') then
       mass=12.0107d0
    else if (lbl.eq.'N') then
       mass=14.0067d0
    else if (lbl.eq.'O') then
       mass=15.9994d0
    else
       errmsg='The atom type '//trim(lbl)//' is not supported.'&
            //' See function lbl2mass'
    endif

    return

  end function lbl2mass

!######################################################################
  
  function lbl2num(lbl) result(num)

    use constants
    use iomod
    
    implicit none
    
    integer          :: num
    character(len=*) :: lbl

    if (lbl.eq.'H') then
       num=1
    else if (lbl.eq.'C') then
       num=6
    else if (lbl.eq.'N') then
       num=7
    else if (lbl.eq.'O') then
       num=8
    else
       errmsg='The atom type '//trim(lbl)//' is not supported.'&
            //' See function lbl2num'
    endif
    
    return
    
  end function lbl2num
    
!######################################################################

  subroutine getmodes

    use constants
    use global
    use iomod

    implicit none

    integer :: i,j

!----------------------------------------------------------------------
! Read the normal modes from file
!----------------------------------------------------------------------
    if (freqtyp.eq.1) then
       ! G98
       call getmodes_g98
    else if (freqtyp.eq.2) then
       ! CFOUR
       call getmodes_cfour
    else if (freqtyp.eq.3) then
       ! HESSIAN
       call getmodes_hessian
    else if (freqtyp.eq.4) then
       ! Projection2 data file
       call getmodes_projection2
    else if (freqtyp.eq.5) then
       ! Turbomole, aoforce
       call getmodes_aoforce
    endif

!----------------------------------------------------------------------
! Orthogonalise the normal mode vectors
!----------------------------------------------------------------------
    call nmortho

!----------------------------------------------------------------------
! Write the normal modes to file for inspection
!----------------------------------------------------------------------
    call wrmodes

    return

  end subroutine getmodes

!######################################################################

  subroutine getmodes_g98

    use constants
    use global
    use iomod

    implicit none

    integer                          :: unit
    integer                          :: i,j,n,nm,nrd,ncurr
    real(d), dimension(ncoo,ncoo)    :: matrix
    real(d), dimension(10)           :: xdum
    real(d)                          :: s2
    logical                          :: found
    character(len=120)               :: string
    character(len=16), dimension(10) :: buffer

!----------------------------------------------------------------------
! Open the frequency file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=freqfile,form='formatted',status='old')

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    matrix=0.0d0

!----------------------------------------------------------------------
! Get the frequencies
!----------------------------------------------------------------------
100 continue

    read(unit,'(a)',end=999) string

    if (string(2:30) .ne. 'Harmonic frequencies (cm**-1)') go to 100

    nrd = ((nmodes-1)/5) + 1

110 continue
    read(unit,'(a)',end=900) string
    if (string(8:22) .ne. 'Frequencies ---') go to 110

    found=.true.
    backspace(unit)
    backspace(unit)
    backspace(unit)

    nm=0
    do n=1,nrd
       ncurr=min(5,nmodes-5*(n-1))
       read(unit,*)
       read(unit,'(26x,5a10)') (buffer(j),j=1,ncurr)
       read(unit,'(23x,5f10.4)',err=900) (xdum(j),j=1,ncurr)       
       do j=1,ncurr
          nm=nm+1
          nmlab(nm)=buffer(j)
          freq(nm)=xdum(j)
       enddo
120    continue
       read(unit,'(a)',end=999) string
       if (string(2:20) .ne. 'Coord Atom Element:') go to 120
       do j=1,ncoo
          read(unit,'(a)',err=900) string
          read(string,20) (xdum(i),i=1,ncurr)
          nm=nm-ncurr
          do i=1,ncurr
             nm=nm+1
             matrix(j,nm)=xdum(i)
          enddo
       enddo
    enddo
20  format(23x,5f10.5)

!----------------------------------------------------------------------
! Close the frequency file
!----------------------------------------------------------------------
    close(unit)

!-----------------------------------------------------------------------
! Scale to mass-weighted x to obtain true normal mode vectors
!
! N.B. This has to be done as Gaussian prints the normal mode vectors
!      in terms of non-mass-weighted Cartesians
!-----------------------------------------------------------------------
    do nm=1,nmodes
       do j=1,ncoo
          matrix(j,nm)=matrix(j,nm)*sqrt(mass(j))
       enddo
    enddo

!-----------------------------------------------------------------------
! Normalise the normal mode vectors
!-----------------------------------------------------------------------
    do i=1,nmodes
       matrix(:,i)=matrix(:,i) &
            /sqrt(dot_product(matrix(:,i),matrix(:,i)))
    enddo

!-----------------------------------------------------------------------
! Convert frequencies to eV
!-----------------------------------------------------------------------
    do i=1,nmodes
       freq(i)=freq(i)*invcm2ev
    enddo

!-----------------------------------------------------------------------
! Save the normal modes in the nmcoo array
!-----------------------------------------------------------------------
    nmcoo=matrix(1:ncoo,1:nmodes)

!-----------------------------------------------------------------------
! Gaussian flags imaginary frequencies using a minus sign - remove these
!-----------------------------------------------------------------------
    freq=abs(freq)
    
    return

900 continue
    errmsg='Incorrect normal mode format. Use IOP(7/8=11)'
    call error_control

999 continue
    errmsg='Problem reading the normal modes in: '//trim(freqfile)
    call error_control

  end subroutine getmodes_g98

!######################################################################

  subroutine getmodes_cfour

    use constants
    use iomod
    use global

    implicit none

    integer                           :: unit,i,j,k,lim1,lim2
    real(d), dimension(ncoo,ncoo)     :: hess
    real(d), dimension(ncoo+3,ncoo+3) :: dumhess
    real(d), dimension(nmodes)        :: cffreq
    character(len=120)                :: string


!**********************************************************************
! Note that cfour outputs the normal mode vectors to only a few
! decimal places. Therefore, we construct the normal modes ourself
! from the Hessian, which is written to a decent level of precision
! in the FCMFINAL file.
!**********************************************************************


!----------------------------------------------------------------------
! Read the Hessian from the FCMFINAL file
!----------------------------------------------------------------------
    ! Open the FCMFINAL file
    call freeunit(unit)
    open(unit,file=trim(freqfile)//'/FCMFINAL',form='formatted',&
         status='old')

    ! Read the FCMFINAL file
    read(unit,*)

    if (ldum) then
       ! Dummy atom present
       ! (1) Read the Hessian including the dummy atom
       do i=1,ncoo+3
          do j=1,natm+1
             read(unit,'(3F20.10)') (dumhess(i,k), k=j*3-2,j*3)
          enddo
       enddo
       ! (2) Remove the dummy atom contributions
       lim1=idum*3-2
       lim2=idum*3
       do i=1,ncoo+3
          if (i.ge.lim1.and.i.le.lim2) cycle
          do j=1,ncoo+3
             if (j.ge.lim1.and.j.le.lim2) cycle
             if (i.lt.lim1.and.j.lt.lim1) then
                hess(i,j)=dumhess(i,j)
             else if (i.lt.lim1.and.j.ge.lim1) then
                hess(i,j-3)=dumhess(i,j)
             else if (i.ge.lim1.and.j.lt.lim1) then
                hess(i-3,j)=dumhess(i,j)
             else if (i.ge.lim1.and.j.ge.lim1) then
                hess(i-3,j-3)=dumhess(i,j)
             endif
          enddo
       enddo
    else
       ! No dummy atom
       do i=1,ncoo
          do j=1,natm
             read(unit,'(3F20.10)') (hess(i,k), k=j*3-2,j*3)
          enddo
       enddo
    endif

    ! Close the FCMFINAL file
    close(unit)

!----------------------------------------------------------------------
! Calculate the normal mode vectors from the Hessian
!----------------------------------------------------------------------
    call hess2nm(hess)

!----------------------------------------------------------------------
! Consistency check: read the CFOUR log file frequencies and make sure
! that our frequencies match.
!
! Note that this check only makes sense if we are not deuterating the
! molecule
!----------------------------------------------------------------------    
    if (.not.ldeuterate) then
       
       call freeunit(unit)
       open(unit,file=trim(freqfile)//'/cfour.log')
       
5      read(unit,'(a)',end=888) string
       if (index(string,'rotational projection').eq.0) goto 5
       
       do i=1,7
          read(unit,*)
       enddo
       
       do i=1,nmodes
          read(unit,'(24x,F10.4)') cffreq(i)
          if (abs(cffreq(i)-freq(i)/invcm2ev).gt.1.0d0) then
             errmsg='Mismatch between calculated frequencies:'
             write(errmsg(len_trim(errmsg):),'(2(x,F10.4))') &
                  cffreq(i),freq(i)/invcm2ev
             call error_control
          endif
       enddo
       
       close(unit)

    endif
       
!----------------------------------------------------------------------
! Read the symmetry labels from the CFOUR log file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=trim(freqfile)//'/cfour.log')

10  read(unit,'(a)',end=999) string
    if (index(string,'Normal Coordinate Analysis').eq.0) goto 10

    do i=1,12
       read(unit,*)
    enddo

    do i=1,nmodes
       read(unit,'(8x,a3)') nmlab(i)
    enddo

    close(unit)

    return

888 continue
    errmsg='The frequencies could not be found in: '&
         //trim(freqfile)//'/cfour.log'
    call error_control

999 continue
    errmsg='The Normal Coordinate Analysis section couldn''t &
         be found in: '//trim(freqfile)//'/cfour.log'
    call error_control

  end subroutine getmodes_cfour

!######################################################################

  subroutine getmodes_hessian

    use constants
    use iomod
    use global

    implicit none
    
    integer                       :: unit,i,j
    real(d), dimension(ncoo,ncoo) :: hess

!----------------------------------------------------------------------
! Read the Hessian
!----------------------------------------------------------------------
    ! Open the Hessian file
    call freeunit(unit)
    open(unit,file=freqfile,form='formatted',status='old')

    ! Read the Hessian
    do i=1,natm+1
       read(unit,*)
    enddo
    do i=1,ncoo
       read(unit,*) (hess(i,j),j=1,ncoo)
    enddo

    ! Close the Hessian file
    close(unit)

!----------------------------------------------------------------------
! Calculate the normal mode vectors from the Hessian
!----------------------------------------------------------------------
    call hess2nm(hess)

!----------------------------------------------------------------------
! Assign the symmetry labels: only C1 symmetry is supported for now
!----------------------------------------------------------------------
    nmlab(1:nmodes)='A'
    
    return

  end subroutine getmodes_hessian

!######################################################################

  subroutine getmodes_projection2

    use constants
    use iomod
    use global
    
    implicit none

    integer                           :: unit,idum,i
    real(d), dimension(ncoo)          :: xdum,mdum
    real(d), dimension(ncoo,ncoo)     :: sthess
    character(len=120)                :: header
    character(len=2), dimension(natm) :: ldum
    
!-----------------------------------------------------------------------
! Open file
!-----------------------------------------------------------------------
    open(unit,file=freqfile,form='unformatted',status='old')

!-----------------------------------------------------------------------
! Read past the file header, no. coordinates, geometry, masses and
! atom labels
!-----------------------------------------------------------------------
    ! Header
    read(unit) header

    ! No. coordinates
    read(unit) idum

    ! Reference geometry
    read(unit) xdum

    ! Masses
    read(unit) mdum

    ! Atom labels
    read(unit) ldum

!-----------------------------------------------------------------------
! Read in the coordinate vectors (in terms of mass-weighted Cartesians)
!-----------------------------------------------------------------------
    ! Coordinate vectors
    read(unit) nmcoo

!-----------------------------------------------------------------------
! Determine the 'frequencies' from the diagonal elements of the
! similarity transformed Hessian
!-----------------------------------------------------------------------
    ! Similarity transformed Hessian
    read(unit) sthess

    ! 'Frequencies' in eV
    do i=1,ncoo
       freq(i)=sqrt(abs(sthess(i,i)))*0.6373641d0
    enddo
    
!-----------------------------------------------------------------------
! Close file
!-----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine getmodes_projection2

!######################################################################

  subroutine getmodes_aoforce

    use constants
    use global
    use iomod

    implicit none

    integer                           :: unit
    integer                           :: i,j,k,ilbl,jlbl,nm,nblock,&
                                         indx1,indx2,indx
    real*8, dimension(ncoo,ncoo)      :: matrix1,matrix
    real*8, dimension(ncoo)           :: freq1
    character(len=3), dimension(ncoo) :: nmlab1
    character(len=120)                :: string

!----------------------------------------------------------------------
! Open the frequency file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=freqfile,form='formatted',status='old')

!----------------------------------------------------------------------
! Initialisation
!----------------------------------------------------------------------
    matrix=0.0d0

!----------------------------------------------------------------------
! Read in the normal modes
! New: we will read in all 3N normal modes and later on filter out
! those of zero frequency. This is necessary as imaginary frequency
! modes come first in the AOFORCE output.
!----------------------------------------------------------------------
    ! No. blocks of normal modes in the output
    nblock=ceiling(real(ncoo)/6)

    ! Read to the start of the normal mode section
5   read(unit,'(a)',end=100) string
    if (index(string,'|dDIP/dQ|').eq.0) goto 5
    do i=1,10
       backspace(unit)
    enddo

    ! Read blocks of normal modes
    do i=1,nblock

       ! Indices of the first and last mode in the block
       indx1=(i-1)*6+1
       indx2=min(i*6,ncoo)

       ! Frequencies: this is quite convoluted due to the fact
       ! that the imaginary frequencies are printed as iomega,
       ! so we need to detect and remove the i's.
       do j=1,4
          read(unit,*)
       enddo
       read(unit,'(20x,a)') string

       do j=indx1,indx2
          ! Trim off the leading whitespace
          string=adjustl(string)
          ! Start of the current frequency in the string
          if (string(1:1).eq.'i') then
             ilbl=2
          else
             ilbl=1
          endif
          ! End of the current frequency in the string
          jlbl=index(string,' ')-1
          ! Read in the frequency of the current mode
          read(string(ilbl:jlbl),*) freq1(j)
          ! Remove the current frequency from the string
          do k=1,jlbl
             string(k:k)=''
          enddo
       enddo

       ! Symmetry labels
       read(unit,*)
       read(unit,'(19x,6(6x,a3))') (nmlab1(j),j=indx1,indx2)

       ! Normal mode vectors
       do j=1,8
          read(unit,*)
       enddo
       do j=1,ncoo
          read(unit,'(20x,6(F9.5))') matrix1(j,indx1:indx2)
       enddo

       ! Skip to the end of this block
       read(unit,*)
       read(unit,*)
              
    enddo
    
!----------------------------------------------------------------------
! Close the frequency file
!----------------------------------------------------------------------
    close(unit)

!----------------------------------------------------------------------
! Filter out the zero frequency modes
!----------------------------------------------------------------------
    indx=0
    do i=1,ncoo
       if (freq1(i).eq.0.0d0) cycle
       indx=indx+1
       freq(indx)=freq1(i)
       nmlab(indx)=nmlab1(i)
       matrix(:,indx)=matrix1(:,i)
    enddo

!-----------------------------------------------------------------------
! Scale to mass-weighted x to obtain true normal mode vectors
!
! N.B. This has to be done as aoforce prints the normal mode vectors
!      in terms of non-mass-weighted Cartesians
!-----------------------------------------------------------------------
    do nm=1,nmodes
       do j=1,ncoo
          matrix(j,nm)=matrix(j,nm)*sqrt(mass(j))
       enddo
    enddo

!-----------------------------------------------------------------------
! Convert frequencies to eV
!-----------------------------------------------------------------------
    do i=1,nmodes
       freq(i)=freq(i)*invcm2ev
    enddo

!-----------------------------------------------------------------------
! Save the normal modes in the nmcoo array
!-----------------------------------------------------------------------
    nmcoo=matrix(1:ncoo,1:nmodes)

    return

100 continue
    errmsg='The normal modes could not be found in the file: '&
         //trim(freqfile)
    call error_control

  end subroutine getmodes_aoforce
    
!######################################################################

  subroutine hess2nm(hess)

    use constants
    use iomod
    use global
    use utils

    implicit none

    integer                       :: i,j,k,l,e2,error,unit
    integer, dimension(ncoo)      :: indx
    real(d), dimension(ncoo,ncoo) :: hess,proj,phess,eigvec
    real(d), dimension(ncoo)      :: eigval
    real(d), dimension(3*ncoo)    :: work

!----------------------------------------------------------------------
! Mass-weight the Hessian
!----------------------------------------------------------------------
    do i=1,ncoo
       do j=1,ncoo
          hess(i,j)=hess(i,j)/sqrt(mass(i)*mass(j))
       enddo
    enddo

!----------------------------------------------------------------------
! Project out the rotational and translational DOFs
!----------------------------------------------------------------------
    ! Construct the projector onto the complement of the
    ! translation-rotation subspace
    call rtproj(proj)

    ! Project out the rotational and translational DOFs
    phess=matmul(proj,matmul(hess,proj))

!----------------------------------------------------------------------
! Diagonalise the projected mass-weighted Hessian
!----------------------------------------------------------------------
    eigvec=phess
    e2=3*ncoo

    call dsyev('V','U',ncoo,eigvec,ncoo,eigval,work,e2,error)

    if (error.ne.0) then
       errmsg='Diagonalisation of the projected Hessian failed in &
            subroutine hess2nm'
       call error_control
    endif

!----------------------------------------------------------------------
! Sort the normal modes by absolute eigenvalues
!----------------------------------------------------------------------
    eigval=abs(eigval)
    call dsortindxa1('A',ncoo,eigval,indx)

!----------------------------------------------------------------------
! Frequencies in ev
!----------------------------------------------------------------------
    do i=7,ncoo
       freq(i-6)=sqrt(abs(eigval(indx(i))))*5140.8096d0*invcm2ev
    enddo

!-----------------------------------------------------------------------
! Normal mode vectors
!-----------------------------------------------------------------------
    do i=7,ncoo
       nmcoo(:,i-6)=eigvec(:,indx(i))
    enddo

    return

  end subroutine hess2nm

!######################################################################

  subroutine rtproj(proj)

    use constants
    use iomod
    use global

    implicit none

    integer                       :: i,j,k,l
    integer, dimension(6)         :: ipiv
    integer                       :: info
    real(d), dimension(ncoo,ncoo) :: proj,rmat
    real(d), dimension(6,ncoo)    :: rtvec
    real(d), dimension(6,6)       :: smat,invsmat
    real(d), dimension(ncoo,6)    :: bmat
    real(d), dimension(6)         :: work
    logical(kind=4)               :: lcheck

!------------------------------------------------------------------
! Initialise arrays
!------------------------------------------------------------------
    rtvec=0.0d0

!------------------------------------------------------------------
! Vectors 1-3: translation along the three Cartesian axes
!------------------------------------------------------------------
    ! Loop over the translational DOFs
    do i=1,3
       ! Construct the vector for the current DOF
       do j=1,natm
          k=j*3-3+i
          rtvec(i,k)=sqrt(mass(j*3))
       enddo
    enddo

!------------------------------------------------------------------
! Vectors 4-6: infinitesimal displacements corresponding to
!              rotation about the three Cartesian axes
!------------------------------------------------------------------
    ! Rotation about the x-axis
    do i=1,natm
       j=i*3-1
       k=i*3
       rtvec(4,j)=sqrt(mass(i*3))*xcoo0(k)
       rtvec(4,k)=-sqrt(mass(i*3))*xcoo0(j)
    enddo

    ! Rotation about the y-axis
    do i=1,natm
       j=i*3-2
       k=i*3
       rtvec(5,j)=-sqrt(mass(i*3))*xcoo0(k)
       rtvec(5,k)=sqrt(mass(i*3))*xcoo0(j)
    enddo

    ! Rotation about the z-axis
    do i=1,natm
       j=i*3-2
       k=i*3-1
       rtvec(6,j)=sqrt(mass(i*3))*xcoo0(k)
       rtvec(6,k)=-sqrt(mass(i*3))*xcoo0(j)
    enddo

!------------------------------------------------------------------
! Calculate the projector R onto the translational and rotational
! DOFs using R=b*S^-1*b^T, where S=vec^T*vec.
!
! Here, R <-> rmat, S <-> smat, b <-> bmat (matrix of vectors)
!------------------------------------------------------------------
    ! Construct the b-matrix
    bmat=transpose(rtvec)

    ! Calculate the S-matrix
    smat=matmul(transpose(bmat),bmat)

    ! Invert the S-matrix
    invsmat=smat
    call dgetrf(6,6,invsmat,6,ipiv,info)
    if (info.ne.0) then
       errmsg='LU factorisation of the S-matrix failed'
       call error_control
    endif
    call dgetri(6,invsmat,6,ipiv,work,6,info)
    if (info.ne.0) then
       errmsg='Diagonalisation of the S-matrix failed'
       call error_control       
    endif
    
    ! Calculate the projection matrix R <-> rmat
    rmat=matmul(bmat,matmul(invsmat,transpose(bmat)))

!------------------------------------------------------------------
! Construct the projector onto the complement of the
! translation-rotation subspace: P=1-R
!------------------------------------------------------------------
    ! 1
    proj=0.0d0
    do i=1,ncoo
       proj(i,i)=1.0d0
    enddo

    ! 1-R
    proj=proj-rmat

    return

  end subroutine rtproj

!######################################################################

  subroutine nmortho

    use constants
    use global
    use channels

    implicit none

    integer :: i,i1,j
    real(d) :: x
      
    do i=1,nmodes
       
       do i1=1,i-1
          x=0.0d0
          do j=1,ncoo
             x=x+nmcoo(j,i)*nmcoo(j,i1)
          enddo
          do j=1,ncoo
             nmcoo(j,i)=nmcoo(j,i)-x*nmcoo(j,i1)
          enddo
       enddo
    
       x=0.0d0
       do j=1,ncoo
          x=x+nmcoo(j,i)*nmcoo(j,i)
       enddo
       
       x=1.0d0/sqrt(x)
       do j=1,ncoo
          nmcoo(j,i)=x*nmcoo(j,i)
       enddo
    
    enddo

    return

  end subroutine nmortho

!#######################################################################

  subroutine wrmodes

    use constants
    use global
    use iomod

    implicit none

    integer          :: unit,i,j,k
    character(len=2) :: amode

!----------------------------------------------------------------------
! Open the output file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file='modes.xyz',form='formatted',status='unknown')

!----------------------------------------------------------------------
! Write the normal modes and frequencies to file
!----------------------------------------------------------------------
    do i=1,nmodes
       write(amode,'(i2)') i
       write(unit,'(i2)') natm
       write(unit,'(a,2x,F10.4,x,a)') &
            'Q'//trim(adjustl(amode))//',',freq(i)/invcm2ev,'cm-1'
       do j=1,natm
          write(unit,'(a2,6(2x,F10.7))') atlbl(j),&
               (xcoo0(k)/ang2bohr,k=j*3-2,j*3),&
               (nmcoo(k,i)/sqrt(mass(k)),k=j*3-2,j*3)
       enddo
    enddo

!----------------------------------------------------------------------
! Close the output file
!----------------------------------------------------------------------
    close(unit)

    return

  end subroutine wrmodes

!#######################################################################
! nmcoo transforms from nmodes to coo  x = nmcoo*Q
! coonm transforms from coo to nmodes  Q = coonm*(x-x0)
!
! freq in eV, mass in amu, x in non-mass-weighted Angstrom
!#######################################################################

  subroutine nm2xmat

    use constants
    use global

    implicit none

    integer :: i,j

!-----------------------------------------------------------------------
! Transposition of nmcoo
!-----------------------------------------------------------------------
    do j=1,nmodes         
       coonm(j,:)=nmcoo(:,j)
    enddo
      
!-----------------------------------------------------------------------
! Multiply matrix by mass and frequency factors
! "frequencies" in eV and masses in amu
!-----------------------------------------------------------------------
    do j=1,ncoo
       do i=1,nmodes
          nmcoo(j,i)=nmcoo(j,i)/(15.4644d0*sqrt(freq(i)*mass(j)))
          coonm(i,j)=coonm(i,j)*(15.4644d0*sqrt(freq(i)*mass(j)))
       enddo
    enddo
    
    return
  
  end subroutine nm2xmat

!######################################################################
! deuterate: changes the masses of any hydrogen atoms to the mass of
!            of the deuterium atom
!######################################################################

  subroutine deuterate

    use constants
    use global
    use iomod
    
    implicit none

    integer :: i

    do i=1,natm
       if (atnum(i).eq.1) mass(i*3-2:i*3)=2.01410177811d0
    enddo

    return
    
  end subroutine deuterate
    
!######################################################################
! getnatm_freqfile: Determines the no. atoms, natm, from a frequency
!                   file/directory
!######################################################################
  
  subroutine getnatm_freqfile

    use constants
    use global
    use iomod
    
    implicit none
    
    if (freqtyp.eq.1) then
       ! G98
       errmsg='Currently, G98 output files are not supported in &
            subroutine getnatm_freqfile'
       call error_control
    else if (freqtyp.eq.2) then
       ! CFOUR
       call getnatm_freqfile_cfour(freqfile)
    else if (freqtyp.eq.3) then
       ! Hessian file
       call getnatm_freqfile_hessian(freqfile)
    else if (freqtyp.eq.4) then
       ! Projection2 data file: not yet supported here
       errmsg='You need to write the getnatm_freqfile_projection2 &
            subroutine...'
       call error_control
    endif
    
    return
    
  end subroutine getnatm_freqfile

!######################################################################

  subroutine getnatm_freqfile_cfour(filename)

    use constants
    use global
    use iomod
    
    implicit none

    integer            :: unit
    logical            :: found
    character(len=*)   :: filename
    character(len=120) :: string

!----------------------------------------------------------------------
! First check to make sure that the cfour.log file exists
!----------------------------------------------------------------------
    inquire(file=trim(filename)//'/cfour.log',exist=found)

    if (.not.found) then
       errmsg='The CFOUR log file is assumed to be named cfour.log. &
            This file could not be found in: '//trim(filename)
       call error_control
    endif

!----------------------------------------------------------------------
! Open the CFOUR log file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=trim(filename)//'/cfour.log',form='formatted',&
         status='old')
    
!----------------------------------------------------------------------
! Read to the Cartesian coordinates
!----------------------------------------------------------------------
5   read(unit,'(a)',end=999) string
    if (index(string,'Coordinates (in bohr)').eq.0) goto 5

    read(unit,*)
    read(unit,*)
    
!----------------------------------------------------------------------
! Determine the number of atoms
!----------------------------------------------------------------------
    natm=0
    
10  read(unit,'(a)') string
    if (string(2:2).ne.'-') then
       natm=natm+1
       goto 10
    endif

!----------------------------------------------------------------------
! Close the CFOUR log file
!----------------------------------------------------------------------
    close(unit)
    
    return

999 continue
    errmsg='The Cartesian coordinate section could not be found in: '&
         //trim(filename)//'/cfour.log'
    call error_control
    
  end subroutine getnatm_freqfile_cfour

!######################################################################

  subroutine getnatm_freqfile_hessian(filename)

    use constants
    use global
    use iomod
    
    implicit none

    integer                         :: unit
    character(len=*)                :: filename
    character(len=120)              :: string
    character(len=1), dimension(52) :: alphabet
    
    alphabet=(/ 'a','b','c','d','e','f','g','h','i','j','k','l','m',&
         'n','o','p','q','r','s','t','u','v','w','x','y','z',&
         'A','B','C','D','E','F','G','H','I','J','K','L','M',&
         'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'/)
    
    !print*,alphabet(1)
    !stop

!----------------------------------------------------------------------
! Open the Hessian file
!----------------------------------------------------------------------
    call freeunit(unit)
    open(unit,file=filename,form='formatted',status='old')

!----------------------------------------------------------------------
! Read the number of atoms from the Hessian file
!----------------------------------------------------------------------
    natm=0
    
    read(unit,*)
    
5   continue
    read(unit,'(a)') string

    ! Does the current line contain an atom name?
    if (sum(scan(string,alphabet,.true.)).ne.0) then
       natm=natm+1
       goto 5       
    endif

!----------------------------------------------------------------------
! Close the Hessian file
!----------------------------------------------------------------------
    close(unit)
    
    return
    
  end subroutine getnatm_freqfile_hessian

!######################################################################

  subroutine uppercase(string)
      
    implicit none
    
    integer*8    ::  i,j,length
    character(*) :: string
    
    length=len(string)
    
    do j = 1,length
       if(string(j:j).ge."a".and.string(j:j).le."z")&
            string(j:j)=achar(iachar(string(j:j))-32)
    enddo
    
    return

  end subroutine uppercase
  
!######################################################################
  
end module ioqc
